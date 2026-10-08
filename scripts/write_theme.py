#!/usr/bin/env python3
"""Write the exported theme for companion apps (see docs/THEME.md).

Usage: write_theme.py <json>

Writes $XDG_CONFIG_HOME/quickshell-island/theme.json, falling back to
~/.config. The file is replaced atomically so readers never see a partial
write, and is left untouched when the content is already up to date.
"""
import json
import os
import sys
import tempfile


def theme_path():
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config_home, "quickshell-island", "theme.json")


def write_theme(text, path):
    """Write `text` to `path`. Returns False if the file already had that content."""
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass

    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".theme-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise
    return True


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: write_theme.py <json>\n")
        return 2
    # Parse and re-serialize so a malformed argument never reaches the file
    text = json.dumps(json.loads(sys.argv[1]), indent=2) + "\n"
    write_theme(text, theme_path())
    return 0


if __name__ == "__main__":
    sys.exit(main())
