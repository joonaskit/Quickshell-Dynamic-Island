#!/usr/bin/env python3
"""Export the shell's configuration to one file, and import it again.

Usage:
  settings_backup.py export <file> [--usage] [--with-secrets] [--sections settings,dock,usage]
  settings_backup.py import <file> [--sections settings,dock,usage]

Add --json for one line of JSON instead of text (used by BackupService), and
--dir <path> to work on a config directory other than the shell's own.

An export holds settings.json and dock_pinned.json. The launcher's usage history
(launcher_usage.json) is personal, so it is only included with --usage. The keys
in PRIVATE_KEYS (the Hue bridge key and device ids) are left out unless
--with-secrets is given, so an export is safe to share.

An import is checked before anything is written. The files it replaces are
copied to a backup folder first, and that folder is printed. The running shell
must then reload them: ./run.sh --import does that.

The format is documented in docs/CONFIG_EXPORT.md.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

FORMAT = "quickshell-island-config"
VERSION = 1

# section name -> the file it is stored in
SECTION_FILES = {
    "settings": "settings.json",
    "dock": "dock_pinned.json",
    "usage": "launcher_usage.json",
}
DEFAULT_EXPORT = ("settings", "dock")

# Settings that belong to this machine: a credential and the ids of paired devices
PRIVATE_KEYS = ("hueBridgeIp", "hueAppKey", "hueLightId", "kdeConnectDeviceId")

SHELL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


class BackupError(Exception):
    pass


def validate_section(name, value):
    """Raise BackupError unless `value` has the shape of that section's file."""
    if name == "settings":
        if not isinstance(value, dict):
            raise BackupError("the settings section is not an object")
    elif name == "dock":
        if not isinstance(value, list):
            raise BackupError("the dock section is not a list")
        for app in value:
            if not isinstance(app, dict) or not isinstance(app.get("id"), str) or not app["id"]:
                raise BackupError("the dock section has an entry without an id")
    elif name == "usage":
        if not isinstance(value, dict):
            raise BackupError("the usage section is not an object")
        for entry in value.values():
            if not isinstance(entry, dict) or not isinstance(entry.get("count"), (int, float)) \
                    or not isinstance(entry.get("last"), (int, float)):
                raise BackupError("the usage section has a malformed entry")


def build_bundle(sections, shell_version="", with_secrets=False, now=None):
    """The export document for {section name: parsed file content}."""
    out = {}
    for name, value in sections.items():
        validate_section(name, value)
        if name == "settings" and not with_secrets:
            value = {k: v for k, v in value.items() if k not in PRIVATE_KEYS}
        out[name] = value
    return {
        "format": FORMAT,
        "version": VERSION,
        "shellVersion": shell_version,
        "exportedAt": (now or datetime.now().astimezone()).isoformat(timespec="seconds"),
        "sections": out,
    }


def parse_bundle(text):
    """The valid, known sections of an export file's text. Raises BackupError for anything else."""
    try:
        data = json.loads(text)
    except ValueError as exc:
        raise BackupError("the file is not valid JSON") from exc
    if not isinstance(data, dict) or data.get("format") != FORMAT:
        raise BackupError("the file is not a Quickshell Island export")
    version = data.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        raise BackupError("the export has no valid format version")
    if version > VERSION:
        raise BackupError(f"the export was made by a newer version of the shell (format {version})")
    sections = data.get("sections")
    if not isinstance(sections, dict):
        raise BackupError("the export has no sections")
    known = {name: value for name, value in sections.items() if name in SECTION_FILES}
    if not known:
        raise BackupError("the export has nothing to import")
    for name, value in known.items():
        validate_section(name, value)
    return known


def merge_settings(imported, current):
    """Imported settings, keeping this machine's private values where the export has none."""
    merged = dict(imported)
    for key in PRIVATE_KEYS:
        if key not in merged and key in current:
            merged[key] = current[key]
    return merged


def missing_apps(dock, installed):
    """Names of pinned apps whose desktop file is not in `installed` (a set of file names)."""
    missing = []
    for app in dock:
        desktop = app.get("desktopFile")
        if isinstance(desktop, str) and desktop and desktop not in installed:
            missing.append(str(app.get("name") or app["id"]))
    return missing


def installed_desktop_files():
    home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs = [home] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    names = set()
    for base in dirs:
        try:
            names.update(n for n in os.listdir(os.path.join(base, "applications")) if n.endswith(".desktop"))
        except OSError:
            pass
    return names


def shell_version(directory):
    try:
        result = subprocess.run(["git", "-C", directory, "describe", "--tags", "--always", "--dirty"],
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def read_json(path):
    with open(path) as f:
        return json.load(f)


def write_json(path, value):
    """Write through a temporary file, so a failure never leaves half a config behind."""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(value, f, indent=2)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def backup_root():
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(state, "quickshell-island", "backups")


def check_names(only):
    for name in only:
        if name not in SECTION_FILES:
            raise BackupError(f"unknown section: {name}")


def export_config(directory, target, include_usage=False, with_secrets=False, only=None):
    names = list(DEFAULT_EXPORT) + (["usage"] if include_usage else [])
    if only is not None:
        check_names(only)
        names = [name for name in SECTION_FILES if name in only]
    sections = {}
    for name in names:
        path = os.path.join(directory, SECTION_FILES[name])
        if not os.path.exists(path):
            continue
        try:
            sections[name] = read_json(path)
        except ValueError as exc:
            raise BackupError(f"{SECTION_FILES[name]} is not valid JSON") from exc
    if not sections:
        raise BackupError("there is no configuration to export yet")
    bundle = build_bundle(sections, shell_version(directory), with_secrets)
    target = os.path.abspath(os.path.expanduser(target))
    if os.path.isdir(target):
        raise BackupError("the export path is a folder")
    write_json(target, bundle)
    return {"ok": True, "file": target, "sections": list(sections)}


def import_config(directory, source, only=None, backups=None, installed=None):
    try:
        with open(os.path.expanduser(source)) as f:
            sections = parse_bundle(f.read())
    except (OSError, UnicodeDecodeError) as exc:
        raise BackupError(f"cannot read the file: {exc}") from exc
    if only is not None:
        check_names(only)
        sections = {name: value for name, value in sections.items() if name in only}
        if not sections:
            raise BackupError("the export has none of the chosen sections")

    if "settings" in sections:
        try:
            current = read_json(os.path.join(directory, SECTION_FILES["settings"]))
        except (OSError, ValueError):
            current = {}
        sections["settings"] = merge_settings(sections["settings"], current if isinstance(current, dict) else {})

    # Everything is valid from here on: back up, then write
    backup_dir = ""
    existing = [name for name in sections if os.path.exists(os.path.join(directory, SECTION_FILES[name]))]
    if existing:
        backup_dir = os.path.join(backups or backup_root(), datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        os.makedirs(backup_dir)
        for name in existing:
            shutil.copy2(os.path.join(directory, SECTION_FILES[name]), backup_dir)
    for name, value in sections.items():
        write_json(os.path.join(directory, SECTION_FILES[name]), value)

    warnings = []
    if "dock" in sections:
        missing = missing_apps(sections["dock"], installed_desktop_files() if installed is None else installed)
        if missing:
            warnings.append("Pinned apps that are not installed here: " + ", ".join(missing))
    return {"ok": True, "sections": list(sections), "backup": backup_dir, "warnings": warnings}


def main(argv):
    parser = argparse.ArgumentParser(description="Export or import the Quickshell Island configuration.")
    parser.add_argument("command", choices=["export", "import"])
    parser.add_argument("file")
    parser.add_argument("--usage", action="store_true", help="export: include the launcher's usage history")
    parser.add_argument("--with-secrets", action="store_true", help="export: include the Hue bridge key and device ids")
    parser.add_argument("--sections", help="only these sections, comma separated (settings, dock, usage)")
    parser.add_argument("--dir", default=SHELL_DIR, help="the config directory (default: the shell's own)")
    parser.add_argument("--json", action="store_true", help="print the result as one line of JSON")
    args = parser.parse_args(argv[1:])
    try:
        only = [s.strip() for s in args.sections.split(",") if s.strip()] if args.sections else None
        if args.command == "export":
            result = export_config(args.dir, args.file, args.usage, args.with_secrets, only)
        else:
            result = import_config(args.dir, args.file, only)
    except (BackupError, OSError) as exc:
        if args.json:
            print(json.dumps({"ok": False, "error": str(exc)}))
        else:
            print(f"Failed: {exc}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(result))
    elif args.command == "export":
        print(f"Exported {', '.join(result['sections'])} to {result['file']}")
    else:
        print(f"Imported {', '.join(result['sections'])}")
        if result["backup"]:
            print(f"The previous files were saved in {result['backup']}")
        for warning in result["warnings"]:
            print(f"Note: {warning}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
