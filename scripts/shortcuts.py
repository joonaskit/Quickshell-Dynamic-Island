#!/usr/bin/env python3
"""Manage the shell's global keyboard shortcuts in KDE.

Usage:
  shortcuts.py list
  shortcuts.py set <action-id> <qt-key-code>
  shortcuts.py clear <action-id>

Every command prints JSON: {"actions": [...]} plus an "error" string when the
requested change did not happen. A key code is Qt's own integer encoding, the
key plus modifier bits (Meta 0x10000000, Alt 0x08000000, Ctrl 0x04000000,
Shift 0x02000000), which is what QML key events give.

Each shortcut is a KDE "command shortcut": a .desktop file with
X-KDE-GlobalAccel-CommandShortcut=true in the user's applications directory,
bound through kglobalaccel over D-Bus. KDE stores the keys in
kglobalshortcutsrc, so they also show up in System Settings > Shortcuts.
Command shortcuts the user already made by hand that run one of these commands
are reused instead of duplicated.
"""
import configparser
import json
import os
import re
import shlex
import subprocess
import sys

DBUS_NAME = "org.kde.kglobalaccel"
ACTION_UNIQUE = "_launch"  # the single action KDE gives a command shortcut
MANAGED_PREFIX = "quickshell-island-"

META = 0x10000000
ALT = 0x08000000
CTRL = 0x04000000
SHIFT = 0x02000000
MODIFIER_MASK = META | ALT | CTRL | SHIFT
KEY_META = 0x01000022  # how KDE stores a bare Meta shortcut

# (id, group, title, ipc target, function, arguments)
ACTIONS = [
    ("launcher.toggle", "Launcher", "Toggle app launcher", "launcher", "toggle", ()),
    ("launcher.windows", "Launcher", "Open window switcher", "launcher", "windows", ()),
    ("clipboard.toggle", "Clipboard", "Toggle clipboard history", "clipboard", "toggle", ()),
    ("clipboard.incognito", "Clipboard", "Toggle incognito mode", "clipboard", "toggleIncognito", ()),
    ("island.toggle", "Island", "Toggle expanded island", "island", "toggle", ()),
    ("island.expand", "Island", "Expand island", "island", "expand", ()),
    ("island.collapse", "Island", "Collapse island", "island", "collapse", ()),
    ("island.caffeine", "Island", "Toggle caffeine", "island", "toggleCaffeine", ()),
    ("system.dnd", "Island", "Toggle do not disturb", "system", "toggleDnd", ()),
    ("system.volumeUp", "Volume and brightness", "Volume up", "system", "volumeUp", ()),
    ("system.volumeDown", "Volume and brightness", "Volume down", "system", "volumeDown", ()),
    ("system.mute", "Volume and brightness", "Toggle mute", "system", "toggleMute", ()),
    ("system.brightnessUp", "Volume and brightness", "Brightness up", "system", "brightnessUp", ()),
    ("system.brightnessDown", "Volume and brightness", "Brightness down", "system", "brightnessDown", ()),
    ("system.mediaPlayPause", "Media", "Play / pause", "system", "mediaPlayPause", ()),
    ("system.mediaNext", "Media", "Next track", "system", "mediaNext", ()),
    ("system.mediaPrevious", "Media", "Previous track", "system", "mediaPrevious", ()),
    ("system.startTimer5", "Timer and stopwatch", "Start 5 minute timer", "system", "startTimer", ("5",)),
    ("system.startTimer10", "Timer and stopwatch", "Start 10 minute timer", "system", "startTimer", ("10",)),
    ("system.startTimer15", "Timer and stopwatch", "Start 15 minute timer", "system", "startTimer", ("15",)),
    ("system.startTimer30", "Timer and stopwatch", "Start 30 minute timer", "system", "startTimer", ("30",)),
    ("system.toggleTimer", "Timer and stopwatch", "Pause / resume timer", "system", "toggleTimer", ()),
    ("system.cancelTimer", "Timer and stopwatch", "Cancel timer", "system", "cancelTimer", ()),
    ("system.toggleStopwatch", "Timer and stopwatch", "Start / stop stopwatch", "system", "toggleStopwatch", ()),
    ("system.resetStopwatch", "Timer and stopwatch", "Reset stopwatch", "system", "resetStopwatch", ()),
]
ACTIONS_BY_ID = {a[0]: a for a in ACTIONS}

# What `run.sh <word>` means, so shortcuts made by hand with those are recognised
RUN_SH_ALIASES = {
    "launcher": ("launcher", "toggle"), "-l": ("launcher", "toggle"), "--launcher": ("launcher", "toggle"),
    "windows": ("launcher", "windows"), "-w": ("launcher", "windows"), "--windows": ("launcher", "windows"),
    "clipboard": ("clipboard", "toggle"), "-v": ("clipboard", "toggle"), "--clipboard": ("clipboard", "toggle"),
    "toggle": ("island", "toggle"), "-t": ("island", "toggle"), "--toggle": ("island", "toggle"),
    "expand": ("island", "expand"), "-e": ("island", "expand"), "--expand": ("island", "expand"),
    "collapse": ("island", "collapse"), "-c": ("island", "collapse"), "--collapse": ("island", "collapse"),
}

# --- Key codes -------------------------------------------------------------

SPECIAL_KEYS = {
    0x01000000: "Esc", 0x01000001: "Tab", 0x01000002: "Backtab", 0x01000003: "Backspace",
    0x01000004: "Return", 0x01000005: "Enter", 0x01000006: "Ins", 0x01000007: "Del",
    0x01000008: "Pause", 0x01000009: "Print", 0x01000010: "Home", 0x01000011: "End",
    KEY_META: "Meta", 0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down",
    0x01000016: "PgUp", 0x01000017: "PgDown", 0x01000055: "Menu",
    0x01000070: "Volume Down", 0x01000071: "Volume Mute", 0x01000072: "Volume Up",
    0x01000080: "Media Play", 0x01000081: "Media Stop", 0x01000082: "Media Previous",
    0x01000083: "Media Next", 0x01000085: "Media Pause", 0x01000086: "Media Play",
    0x010000b6: "Monitor Brightness Up", 0x010000b7: "Monitor Brightness Down",
}
F1 = 0x01000030
F35 = 0x01000052


def key_name(key):
    if key in SPECIAL_KEYS:
        return SPECIAL_KEYS[key]
    if F1 <= key <= F35:
        return "F%d" % (key - F1 + 1)
    if key == 0x20:
        return "Space"
    if 0x21 <= key <= 0x7E:
        return chr(key).upper()
    return "Key%#x" % key


def key_text(code):
    """Text for a key code, in the order KDE writes it: Meta+Ctrl+Alt+Shift+Key."""
    if code == 0:
        return ""
    parts = []
    for bit, name in ((META, "Meta"), (CTRL, "Ctrl"), (ALT, "Alt"), (SHIFT, "Shift")):
        if code & bit:
            parts.append(name)
    key = code & ~MODIFIER_MASK
    if key:
        parts.append(key_name(key))
    return "+".join(parts)


def valid_code(code):
    """A key that is safe to grab: Meta alone, but not a bare modifier or a plain printable key."""
    key = code & ~MODIFIER_MASK
    if key == 0:
        return False
    if key == KEY_META:
        return code == KEY_META
    if key < 0x01000000:  # printable
        return bool(code & (META | ALT | CTRL))
    return True


# --- Desktop files ---------------------------------------------------------

def applications_dir():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data_home, "applications")


def run_sh_path():
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "run.sh")


def managed_name(action_id):
    return MANAGED_PREFIX + action_id.replace(".", "-") + ".desktop"


def desktop_quote(arg):
    if arg and not re.search(r'[\s"\'\\><~|&;$*?#()`]', arg):
        return arg
    return '"' + re.sub(r'(["`$\\])', r"\\\1", arg) + '"'


def exec_line(action):
    _id, _group, _title, target, function, args = action
    words = [run_sh_path(), "ipc", target, function, *args]
    return " ".join(desktop_quote(w) for w in words)


def parse_exec(line):
    """The IPC command (target, function, *args) an Exec line runs, or None."""
    try:
        tokens = shlex.split(line)
    except ValueError:
        return None
    if not tokens:
        return None
    program = os.path.basename(tokens[0])
    if program == "run.sh":
        rest = tokens[1:]
        if not rest:
            return None
        if rest[0] in ("ipc", "-i", "--ipc"):
            return tuple(rest[1:]) or None
        return RUN_SH_ALIASES.get(rest[0]) if len(rest) == 1 else None
    if program == "quickshell" and "call" in tokens:
        return tuple(tokens[tokens.index("call") + 1:]) or None
    return None


def read_desktop(path):
    """The [Desktop Entry] keys of a file as a dict, or {} if it cannot be read."""
    parser = configparser.RawConfigParser(strict=False, interpolation=None)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
        return dict(parser["Desktop Entry"])
    except (configparser.Error, OSError, UnicodeDecodeError, KeyError):
        return {}


def write_managed_file(action):
    path = os.path.join(applications_dir(), managed_name(action[0]))
    text = "\n".join([
        "[Desktop Entry]",
        "Exec=" + exec_line(action),
        "Name=Quickshell: " + action[2],
        "NoDisplay=true",
        "StartupNotify=false",
        "Type=Application",
        "X-KDE-GlobalAccel-CommandShortcut=true",
        "",
    ])
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return path
    except OSError:
        pass
    os.makedirs(applications_dir(), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)
    return path


def adoptable_files():
    """Hand-made command shortcuts that run one of our commands: {action id: [file names]}."""
    by_command = {(a[3], a[4], *a[5]): a[0] for a in ACTIONS}
    found = {}
    try:
        names = sorted(os.listdir(applications_dir()))
    except OSError:
        return found
    for name in names:
        if not name.endswith(".desktop") or name.startswith(MANAGED_PREFIX):
            continue
        entry = read_desktop(os.path.join(applications_dir(), name))
        if entry.get("X-KDE-GlobalAccel-CommandShortcut", "").lower() != "true":
            continue
        command = parse_exec(entry.get("Exec", ""))
        if command in by_command:
            found.setdefault(by_command[command], []).append(name)
    return found


# --- kglobalaccel ----------------------------------------------------------

class DBusError(Exception):
    pass


def call(path, interface, method, *args):
    cmd = ["busctl", "--user", "--json=short", "call", DBUS_NAME, path, interface, method, *args]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise DBusError(str(e)) from e
    if result.returncode != 0:
        raise DBusError(result.stderr.strip() or "busctl failed")
    try:
        return json.loads(result.stdout)["data"]
    except (ValueError, KeyError):
        return []


def accel(method, *args):
    return call("/kglobalaccel", "org.kde.KGlobalAccel", method, *args)


def component_path(name):
    return "/component/" + re.sub(r"[^A-Za-z0-9_]", "_", name)


def action_id_args(name, friendly):
    return ["4", name, ACTION_UNIQUE, friendly, friendly]


def register(name, friendly):
    accel("doRegister", "as", *action_id_args(name, friendly))


def read_code(name, friendly):
    """The key code bound to a component's action (0 for none)."""
    for _attempt in range(2):
        try:
            data = call(component_path(name), "org.kde.kglobalaccel.Component", "allShortcutInfos")
        except DBusError:
            data = None
        if data is None:
            register(name, friendly)  # KDE only knows the component once it is registered
            continue
        for info in data[0] if data else []:
            if info[0] == ACTION_UNIQUE:
                return next((k for k in info[6] if k), 0)
        return 0
    return 0


def key_owner(code, own_name):
    """'<component>: <action>' of another shortcut that uses this key, or None."""
    for info in (accel("getGlobalShortcutsByKey", "i", str(code)) or [[]])[0]:
        if info[2] != own_name:
            return "%s: %s" % (info[3], info[1])
    return None


def set_keys(name, friendly, code):
    keys = [str(code)] if code else []
    accepted = accel("setShortcut", "asaiu", *action_id_args(name, friendly), str(len(keys)), *keys, "2")
    return accepted[0][0] if accepted and accepted[0] else 0


# --- Commands --------------------------------------------------------------

def backing_file(action_id, adopted):
    """Name of the desktop file holding this action's shortcut, or None if it has none yet."""
    managed = managed_name(action_id)
    if os.path.exists(os.path.join(applications_dir(), managed)):
        return managed
    candidates = adopted.get(action_id, [])
    for name in candidates:
        if read_code(name, name):
            return name
    return candidates[0] if candidates else None


def friendly_name(file_name, action):
    return read_desktop(os.path.join(applications_dir(), file_name)).get("Name") or "Quickshell: " + action[2]


def list_actions(error=None):
    adopted = adoptable_files()
    actions = []
    for action in ACTIONS:
        code = 0
        name = backing_file(action[0], adopted)
        if name:
            if name == managed_name(action[0]):
                write_managed_file(action)  # keeps Exec right if the shell was moved
            try:
                code = read_code(name, friendly_name(name, action))
            except DBusError:
                code = 0
        actions.append({
            "id": action[0],
            "group": action[1],
            "title": action[2],
            "command": " ".join((action[3], action[4], *action[5])),
            "code": code,
            "keys": key_text(code),
        })
    out = {"actions": actions}
    if error:
        out["error"] = error
    return out


def set_action(action_id, code):
    action = ACTIONS_BY_ID[action_id]
    name = backing_file(action_id, adoptable_files())
    if not name:
        name = managed_name(action_id)
        write_managed_file(action)
    friendly = friendly_name(name, action)
    if code:
        owner = key_owner(code, name)
        if owner:
            return "%s is already used by %s" % (key_text(code), owner)
    register(name, friendly)
    if code and set_keys(name, friendly, code) != code:
        return "KDE did not accept %s" % key_text(code)
    if not code:
        set_keys(name, friendly, 0)
        if name == managed_name(action_id):
            # Nothing left worth keeping: drop the component and its desktop file
            accel("unregister", "ss", name, ACTION_UNIQUE)
            call(component_path(name), "org.kde.kglobalaccel.Component", "cleanUp")
            try:
                os.remove(os.path.join(applications_dir(), name))
            except OSError:
                pass
    return None


def main(argv):
    if argv[1:] == ["list"]:
        result = list_actions()
    elif len(argv) in (3, 4) and argv[1] in ("set", "clear") and argv[2] in ACTIONS_BY_ID:
        try:
            code = int(argv[3]) if argv[1] == "set" else 0
        except (ValueError, IndexError):
            code = -1
        if argv[1] == "set" and (code < 0 or not valid_code(code)):
            error = "That key cannot be used on its own"
        else:
            try:
                error = set_action(argv[2], code)
            except DBusError as e:
                error = "Could not reach KDE's shortcut service: %s" % e
        result = list_actions(error)
    else:
        print("Usage: shortcuts.py list | set <action-id> <qt-key-code> | clear <action-id>", file=sys.stderr)
        return 2
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
