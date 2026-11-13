#!/usr/bin/env python3
"""Manage niri's keyboard shortcuts for the settings window.

Usage:
  niri_binds.py list
  niri_binds.py set <action-id> <old-key> <new-key> [--force]
  niri_binds.py remove <action-id> <key>

<old-key> is "" to add a key. Every command prints JSON: {"path", "groups": [...]}
as niri_binds_core.list_actions gives it, plus an "error" string when the change did
not happen, and a "conflict" object ({id, key, title}) when another action has the
key. --force takes the key from that action first.

Binds live in the binds block of niri's config.kdl ($NIRI_CONFIG, else
$XDG_CONFIG_HOME/niri/config.kdl). A change is written to a file beside it, checked
with `niri validate`, and only then moved over it; niri reloads the config by itself.
The previous config is kept as config.kdl.bak-shortcuts. Binds in files the config
includes are not shown.
"""
import json
import os
import shutil
import subprocess
import sys

import niri_binds_core as core

SHELL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def config_path():
    if os.environ.get("NIRI_CONFIG"):
        return os.environ["NIRI_CONFIG"]
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config_home, "niri", "config.kdl")


def output(path, text, error="", conflict=None):
    result = {"path": path, "groups": []}
    if text is not None:
        try:
            result.update(core.list_actions(text, SHELL_DIR))
        except ValueError as e:
            error = error or "Could not read %s: %s" % (path, e)
    if error:
        result["error"] = error
    if conflict:
        result["conflict"] = conflict
    print(json.dumps(result))


def validate(path):
    """Why niri refuses the config at path, or "" when it takes it."""
    if not shutil.which("niri"):
        return "niri is not installed, so the change cannot be checked"
    try:
        proc = subprocess.run(["niri", "validate", "-c", path], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as e:
        return "Could not run niri validate: %s" % e
    if proc.returncode == 0:
        return ""
    return core.validate_error(proc.stderr + proc.stdout)


def write(path, text):
    """Writes the config if niri accepts it. Returns the reason when it does not."""
    real = os.path.realpath(path)  # keep a symlinked config (dotfiles) a symlink
    tmp = os.path.join(os.path.dirname(real), ".config.kdl.island-shortcuts.tmp")
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(text)
        shutil.copymode(real, tmp)
        error = validate(tmp)
        if error:
            return error
        shutil.copy2(real, real + ".bak-shortcuts")
        os.replace(tmp, real)
        return ""
    except OSError as e:
        return "Could not write %s: %s" % (path, e.strerror or e)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv):
    path = config_path()
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        output(path, None, "No niri config at %s" % path)
        return 0
    if not argv or argv[0] == "list":
        output(path, text)
        return 0

    command, args = argv[0], argv[1:]
    force = "--force" in args
    args = [a for a in args if a != "--force"]
    try:
        if command == "set" and len(args) == 3:
            new_text = core.set_key(text, args[0], args[1], args[2], SHELL_DIR, force)
        elif command == "remove" and len(args) == 2:
            new_text = core.remove_key(text, args[0], args[1], SHELL_DIR)
        else:
            output(path, text, "Unknown command: %s" % " ".join(argv))
            return 2
    except core.EditError as e:
        output(path, text, str(e), e.conflict)
        return 0
    except ValueError as e:
        output(path, text, "Could not read %s: %s" % (path, e))
        return 0

    if new_text == text:
        output(path, text)
        return 0
    error = write(path, new_text)
    output(path, text if error else new_text, error)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
