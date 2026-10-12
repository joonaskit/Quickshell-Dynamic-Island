#!/usr/bin/env python3
"""Dependency check: which of the tools and services in deps.json are present.

Usage:
  check_deps.py           a table for the terminal
  check_deps.py --json    the same result as JSON, for the shell and scripts

Each dependency is "found", "missing" or "not-running" (a service that is
installed but not on the bus). The exit code is 1 only when a required
dependency is not found, and 2 when deps.json cannot be read.

Uses the standard library only, so it runs before dbus-python and PyGObject
are installed.
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys

MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "deps.json")

SEVERITIES = ("required", "recommended", "optional")
FOUND, MISSING, NOT_RUNNING = "found", "missing", "not-running"

INSTALL_COMMANDS = {
    "arch": "sudo pacman -S",
    "fedora": "sudo dnf install",
    "opensuse": "sudo zypper install",
    "debian": "sudo apt install",
}

# /etc/os-release ID or ID_LIKE word -> the distro key used in deps.json
DISTRO_IDS = {
    "arch": "arch", "fedora": "fedora", "rhel": "fedora",
    "opensuse": "opensuse", "suse": "opensuse",
    "debian": "debian", "ubuntu": "debian",
}


class Probe:
    """Looks at the real system. Tests pass a fake with the same methods."""

    def __init__(self):
        self._bus_names = {}

    def has_command(self, name):
        return shutil.which(name) is not None

    def has_module(self, name):
        try:
            return importlib.util.find_spec(name) is not None
        except (ImportError, ValueError):
            return False

    def session_type(self):
        return os.environ.get("XDG_SESSION_TYPE", "")

    def bus_names(self, bus):
        """Names on the bus, including ones that would start on demand. Empty when busctl fails."""
        if bus not in self._bus_names:
            lines = _run(["busctl", "--" + bus, "list", "--no-legend", "--no-pager"]).split("\n")
            self._bus_names[bus] = {line.split()[0] for line in lines if line.strip()}
        return self._bus_names[bus]

    def has_unit(self, unit, bus):
        args = ["systemctl", "cat", unit] if bus == "system" else ["systemctl", "--user", "cat", unit]
        return _run(args, output=False)


def _run(args, output=True):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return "" if output else False
    if output:
        return result.stdout if result.returncode == 0 else ""
    return result.returncode == 0


def check_status(check, probe):
    """The status of one deps.json "check" entry."""
    kind = check.get("type")
    if kind == "command":
        if "allOf" in check:
            return FOUND if all(probe.has_command(c) for c in check["allOf"]) else MISSING
        return FOUND if any(probe.has_command(c) for c in check.get("anyOf", [])) else MISSING
    if kind == "python":
        return FOUND if probe.has_module(check["module"]) else MISSING
    if kind == "session":
        return FOUND if probe.session_type() == check["value"] else MISSING
    if kind == "dbus":
        bus = check.get("bus", "user")
        if check["name"] in probe.bus_names(bus):
            return FOUND
        installed = any(probe.has_unit(u, bus) for u in check.get("units", [])) \
            or any(probe.has_command(c) for c in check.get("commands", []))
        return NOT_RUNNING if installed else MISSING
    raise ValueError(f"unknown check type: {kind}")


def detect_distro(os_release):
    """The deps.json distro key for the text of /etc/os-release, or "" when it is not a supported one."""
    fields = {}
    for line in os_release.split("\n"):
        key, sep, value = line.partition("=")
        if sep:
            fields[key.strip()] = value.strip().strip('"').strip("'")
    for word in [fields.get("ID", "")] + fields.get("ID_LIKE", "").split():
        word = word.lower()
        for known, distro in DISTRO_IDS.items():
            if word == known or word.startswith(known + "-"):
                return distro
    return ""


def evaluate(manifest, probe, distro):
    """The full report: every dependency with its status, plus one install command for what is missing."""
    results = []
    for dep in manifest["dependencies"]:
        if dep.get("severity") not in SEVERITIES:
            raise ValueError(f"{dep.get('id')}: unknown severity")
        results.append({
            "id": dep["id"],
            "name": dep["name"],
            "severity": dep["severity"],
            "status": check_status(dep["check"], probe),
            "features": dep.get("features", []),
            "package": dep.get("packages", {}).get(distro, ""),
            "note": dep.get("note", ""),
        })
    packages = []
    for r in results:
        if r["status"] == MISSING and r["package"] and r["package"] not in packages:
            packages.append(r["package"])
    command = f"{INSTALL_COMMANDS[distro]} {' '.join(packages)}" if packages and distro in INSTALL_COMMANDS else ""
    return {
        "distro": distro,
        "ok": not any(r["severity"] == "required" and r["status"] != FOUND for r in results),
        "installCommand": command,
        "dependencies": results,
    }


def format_table(report, color=False):
    def paint(text, code):
        return f"\033[{code}m{text}\033[0m" if color else text

    marks = {FOUND: paint("ok", "32"), MISSING: paint("missing", "31"), NOT_RUNNING: paint("not running", "33")}
    width = max(len(r["name"]) for r in report["dependencies"])
    lines = []
    for severity in SEVERITIES:
        rows = [r for r in report["dependencies"] if r["severity"] == severity]
        if not rows:
            continue
        lines.append(paint(severity.upper(), "1"))
        for r in rows:
            lines.append(f"  {r['name'].ljust(width)}  {marks[r['status']]}")
            if r["status"] == FOUND:
                continue
            lines.append(f"  {' ' * width}    affects: {'; '.join(r['features'])}")
            if r["status"] == NOT_RUNNING:
                lines.append(f"  {' ' * width}    installed, but the service is not running")
            elif r["package"]:
                lines.append(f"  {' ' * width}    package: {r['package']}")
            if r["note"]:
                lines.append(f"  {' ' * width}    {r['note']}")
        lines.append("")

    problems = [r for r in report["dependencies"] if r["status"] != FOUND]
    if not problems:
        lines.append("Everything was found.")
    else:
        required = sum(1 for r in problems if r["severity"] == "required")
        lines.append(f"{len(problems)} not found" + (f", {required} of them required." if required else ", none of them required."))
        if report["installCommand"]:
            lines.append(f"Install the missing packages with:\n  {report['installCommand']}")
        elif not report["distro"]:
            lines.append("Package names are only known for Arch, Fedora, openSUSE and Debian/Ubuntu.")
    return "\n".join(lines)


def main(argv):
    if len(argv) > 2 or (len(argv) == 2 and argv[1] != "--json"):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(MANIFEST) as f:
            manifest = json.load(f)
        try:
            with open("/etc/os-release") as f:
                distro = detect_distro(f.read())
        except OSError:
            distro = ""
        report = evaluate(manifest, Probe(), distro)
    except (OSError, ValueError, KeyError) as exc:
        print(f"Cannot read deps.json: {exc}", file=sys.stderr)
        return 2
    if len(argv) == 2:
        print(json.dumps(report))
    else:
        print(format_table(report, color=sys.stdout.isatty()))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
