"""Checks that every KDE-only command a QML file runs is one that is known to be kept from
running, or hidden, outside KDE Plasma. Under niri such a command fails without a word,
so a new one needs a CompositorService.isKde check, or an availability check, and an
entry below saying which. Run with ./test.sh."""
import os
import re
import subprocess
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# Commands that need KDE Plasma running, or that only exist there: the first word of a
# command list, or a KDE D-Bus service. Lines that ask DepsService about a tool name it
# without running it.
KDE_COMMAND = re.compile(
    r'\[\s*"(kcmshell6|systemsettings|kscreen-doctor|kmenuedit|kreadconfig6|kwriteconfig6|'
    r'plasma-apply-colorscheme)"|"qdbus-qt6",\s*"org\.kde\.[\w.]+"|"org\.kde\.KWin"')

# (file, command) -> how it is kept from running where it cannot work
ALLOWED = {
    ("services/BluetoothService.qml", "kcmshell6"): "settingsCommand: under KDE only",
    ("services/NetworkService.qml", "kcmshell6"): "settingsCommand: under KDE, else only when found",
    ("services/PowerService.qml", "kcmshell6"): "hasSettings: under KDE only",
    ("services/PowerProfileService.qml", "kscreen-doctor"): "lowRefreshProblem: deps.json, KDE only",
    ("services/ScreenService.qml", "kscreen-doctor"): "refresh(): under KDE only",
    ("services/WindowService.qml", "systemsettings"): "openSettings(): when it is installed",
    ("services/NightLightService.qml", "org.kde.KWin"): "available: under KDE only",
    ("dock/DockService.qml", "org.kde.krunner"): "openLaunchpad(): under KDE only",
    ("dock/DockService.qml", "kmenuedit"): "the Edit button shows only when kmenuedit is installed",
    ("dial/DialService.qml", "systemsettings"): "KDE_SETTINGS_TILES are dimmed without systemsettings",
}


def qml_files():
    out = subprocess.run(["git", "ls-files", "*.qml"], cwd=ROOT, capture_output=True, text=True, check=True)
    return [p for p in out.stdout.split() if not p.startswith("tests/")]


def found_commands(text):
    """The KDE-only commands named in a file's text, as short names."""
    names = set()
    text = "\n".join(line for line in text.splitlines() if "DepsService." not in line)
    for m in KDE_COMMAND.finditer(text):
        if m.group(1):
            names.add(m.group(1))
        else:
            names.add(re.search(r'org\.kde\.\w+', m.group(0)).group(0))
    return names


class KdeCommandsTest(unittest.TestCase):
    def test_found_commands(self):
        self.assertEqual(found_commands('command: ["kcmshell6", "kcm_bluetooth"]'), {"kcmshell6"})
        self.assertEqual(found_commands('["qdbus-qt6", "org.kde.krunner", "/App"]'), {"org.kde.krunner"})
        self.assertEqual(found_commands('["busctl", "--user", "call", "org.kde.KWin", "/x"]'), {"org.kde.KWin"})
        self.assertEqual(found_commands('icon: "org.kde.dolphin", command: "dolphin"'), set())
        self.assertEqual(found_commands('id: "systemsettings", ignore: ["kded", "systemsettings"]'), set())
        self.assertEqual(found_commands('DepsService.noneUsable(["systemsettings", "kcmshell6"])'), set())

    def test_every_kde_command_is_accounted_for(self):
        unexplained = []
        for path in qml_files():
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                for name in sorted(found_commands(f.read())):
                    if (path, name) not in ALLOWED:
                        unexplained.append("%s runs %s" % (path, name))
        self.assertEqual(unexplained, [], "KDE-only commands with no entry in ALLOWED (see the docstring)")

    def test_no_stale_entries(self):
        present = set()
        for path in qml_files():
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                present |= {(path, n) for n in found_commands(f.read())}
        self.assertEqual(sorted(set(ALLOWED) - present), [])


if __name__ == "__main__":
    unittest.main()
