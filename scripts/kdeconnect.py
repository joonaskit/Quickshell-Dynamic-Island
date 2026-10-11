#!/usr/bin/env python3
"""KDE Connect helper for KdeConnectService.

Talks to the kdeconnect daemon over the session bus with busctl. Output is JSON.

Commands:
  list                         paired devices with reachability, battery and the actions they offer
  ping <id>                    send a ping
  clipboard <id>               send this computer's clipboard to the device
  ring <id>                    make the device ring (Find my phone)
  share-text <id> <text>       send text
  share-url <id> <url>         send a link
  share-file <id> <path>       send a file
"""
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

SERVICE = "org.kde.kdeconnect"
DAEMON_PATH = "/modules/kdeconnect"
DEVICES = DAEMON_PATH + "/devices"
DEVICE_IFACE = "org.kde.kdeconnect.device"
ID_PATTERN = re.compile(r"^[A-Za-z0-9_]+$")

# action -> (plugin object name, method, argument signature)
ACTIONS = {
    "ping": ("ping", "sendPing", ""),
    "clipboard": ("clipboard", "sendClipboard", ""),
    "ring": ("findmyphone", "ring", ""),
    "share-text": ("share", "shareText", "s"),
    "share-url": ("share", "shareUrl", "s"),
}


class KdeConnectError(Exception):
    pass


def busctl(*args):
    try:
        result = subprocess.run(
            ["busctl", "--user", "--json=short", *args],
            capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise KdeConnectError(str(exc)) from exc
    if result.returncode != 0:
        raise KdeConnectError(result.stderr.strip() or "busctl failed")
    return result.stdout


def plugins_in_tree(paths, device_id):
    """Names of the plugin objects a device currently has, from a list of object paths."""
    prefix = f"{DEVICES}/{device_id}/"
    return {p[len(prefix):] for p in paths if p.startswith(prefix) and "/" not in p[len(prefix):]}


def summarize_device(device_id, props, plugins, battery):
    """The fields the shell uses for one device. battery is the battery plugin's properties or None."""
    has_battery = bool(battery and battery.get("hasBattery") and battery.get("charge", -1) >= 0)
    return {
        "id": device_id,
        "name": props.get("name", device_id),
        "type": props.get("type", "phone"),
        "reachable": bool(props.get("isReachable")),
        "hasBattery": has_battery,
        "charge": battery["charge"] if has_battery else -1,
        "charging": bool(battery and battery.get("isCharging")) if has_battery else False,
        "canPing": "ping" in plugins,
        "canClipboard": "clipboard" in plugins,
        "canShare": "share" in plugins,
        "canRing": "findmyphone" in plugins,
    }


def get_all(path, iface):
    data = json.loads(busctl("call", SERVICE, path, "org.freedesktop.DBus.Properties", "GetAll", "s", iface))
    return {name: value["data"] for name, value in data["data"][0].items()}


def cmd_list():
    out = json.loads(busctl("call", SERVICE, DAEMON_PATH, SERVICE + ".daemon", "devices", "bb", "false", "true"))
    ids = [i for i in out["data"][0] if ID_PATTERN.match(i)]
    paths = busctl("tree", SERVICE, "--list").split("\n")
    devices = []
    for device_id in ids:
        path = f"{DEVICES}/{device_id}"
        props = get_all(path, DEVICE_IFACE)
        plugins = plugins_in_tree(paths, device_id) if props.get("isReachable") else set()
        battery = get_all(path + "/battery", DEVICE_IFACE + ".battery") if "battery" in plugins else None
        devices.append(summarize_device(device_id, props, plugins, battery))
    print(json.dumps({"devices": devices}))


def run_action(action, device_id, argument=None):
    if not ID_PATTERN.match(device_id):
        raise KdeConnectError("bad device id")
    plugin, method, signature = ACTIONS[action]
    args = ["call", SERVICE, f"{DEVICES}/{device_id}/{plugin}", f"{DEVICE_IFACE}.{plugin}", method]
    if signature:
        args += [signature, argument]
    busctl(*args)


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    command, rest = argv[1], argv[2:]
    try:
        if command == "list":
            cmd_list()
        elif command in ("ping", "clipboard", "ring") and len(rest) == 1:
            run_action(command, rest[0])
        elif command in ("share-text", "share-url") and len(rest) == 2:
            run_action(command, rest[0], rest[1])
        elif command == "share-file" and len(rest) == 2:
            path = Path(rest[1]).expanduser().resolve()
            if not path.is_file():
                raise KdeConnectError("not a file")
            run_action("share-url", rest[0], "file://" + quote(str(path)))
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except (KdeConnectError, ValueError, KeyError, IndexError) as exc:
        print(json.dumps({"error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
