#!/usr/bin/env python3
"""Finds the helper scripts the shell runs, for the Health section of the About page.

  helper_health.py scan SHELL_DIR [--owned PID,PID] [--kill]
  helper_health.py versions SHELL_DIR

`scan` prints JSON listing every long-running helper under SHELL_DIR/scripts. A
helper whose pid is not in --owned is stale: a leftover from an earlier shell
that was stopped without its helpers (./run.sh -k stops them, but a crash or a
plain `quickshell kill` does not). With --kill the stale ones get SIGTERM.
"""
import json
import os
import signal
import subprocess
import sys

# Scripts that keep running for as long as the shell does. The others
# (audio_sinks.py list, shortcuts.py, ...) exit on their own.
LONG_RUNNING = {
    "kwin_window_tracker.py": None,
    "hardware_stats.py": None,
    "clipboard_tracker.py": None,
    "activities_bridge.py": None,
    "devices.py": "monitor",
}


def is_long_running(script, args):
    """script is the file name, args what follows it on the command line"""
    if script not in LONG_RUNNING:
        return False
    needed = LONG_RUNNING[script]
    return needed is None or needed in args


def parse_cmdline(raw, scripts_dir):
    """(script name, args after it) when the command line runs a .py file directly
    under scripts_dir, else None. raw is the NUL-separated /proc/PID/cmdline."""
    parts = [p for p in raw.split("\0") if p]
    prefix = scripts_dir.rstrip("/") + "/"
    for i, part in enumerate(parts):
        if part.startswith(prefix) and part.endswith(".py") and "/" not in part[len(prefix):]:
            return part[len(prefix):], parts[i + 1:]
    return None


def find_helpers(shell_dir, proc_root="/proc"):
    """Every running long-running helper under shell_dir/scripts, as dicts with pid and script"""
    scripts_dir = os.path.join(shell_dir, "scripts")
    found = []
    try:
        names = os.listdir(proc_root)
    except OSError:
        return found
    for name in names:
        if not name.isdigit():
            continue
        try:
            with open(os.path.join(proc_root, name, "cmdline"), "rb") as f:
                raw = f.read().decode("utf-8", "replace")
        except OSError:
            continue
        parsed = parse_cmdline(raw, scripts_dir)
        if parsed and is_long_running(*parsed):
            found.append({"pid": int(name), "script": parsed[0]})
    return sorted(found, key=lambda h: (h["script"], h["pid"]))


def mark_stale(helpers, owned):
    """Adds a stale flag: a helper the running shell does not own"""
    owned = set(owned)
    return [dict(h, stale=h["pid"] not in owned) for h in helpers]


def kill_stale(helpers):
    """SIGTERM to each stale helper. Returns the pids that were signalled."""
    killed = []
    for h in helpers:
        if not h["stale"]:
            continue
        try:
            os.kill(h["pid"], signal.SIGTERM)
            killed.append(h["pid"])
        except OSError:
            pass
    return killed


def run(cmd):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return (out.stdout or out.stderr).strip().splitlines()[0]
    except (OSError, subprocess.SubprocessError, IndexError):
        return ""


def versions(shell_dir):
    return {
        "quickshell": run(["quickshell", "--version"]),
        "python": run([sys.executable, "--version"]),
        "commit": run(["git", "-C", shell_dir, "rev-parse", "--short", "HEAD"]),
        "kernel": run(["uname", "-r"]),
    }


def main(argv):
    if len(argv) < 3 or argv[1] not in ("scan", "versions"):
        print(__doc__, file=sys.stderr)
        return 2
    shell_dir = os.path.realpath(argv[2])
    if argv[1] == "versions":
        print(json.dumps(versions(shell_dir)))
        return 0
    owned = []
    if "--owned" in argv:
        value = argv[argv.index("--owned") + 1] if argv.index("--owned") + 1 < len(argv) else ""
        owned = [int(p) for p in value.split(",") if p.isdigit()]
    helpers = mark_stale(find_helpers(shell_dir), owned)
    killed = kill_stale(helpers) if "--kill" in argv else []
    print(json.dumps({"helpers": helpers, "killed": killed}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
