#!/usr/bin/env python3
"""Print whether niri blurs the shell's surfaces, as JSON (niri_blur_core.analyze plus
the config's path). Reads niri's config.kdl ($NIRI_CONFIG, else
$XDG_CONFIG_HOME/niri/config.kdl) and the files it includes. The Glass page of the
settings window runs it under niri; see docs/GLASS.md.
"""
import json
import os
import sys

import niri_blur_core as core
from niri_binds import config_path


def read_tree(path, seen=None, depth=0):
    """The texts of path and then of the files it includes."""
    seen = seen if seen is not None else set()
    real = os.path.realpath(path)
    if real in seen or depth > 8:
        return []
    seen.add(real)
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return []
    texts = [text]
    try:
        for inc in core.includes(text):
            inc_path = os.path.join(os.path.dirname(path), os.path.expanduser(inc))
            texts += read_tree(inc_path, seen, depth + 1)
    except ValueError:
        pass
    return texts


def main():
    path = config_path()
    texts = read_tree(path)
    try:
        result = core.analyze(texts)
    except ValueError as e:
        result = {"error": str(e)}
    result["path"] = path
    result["found"] = bool(texts)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
