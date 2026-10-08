#!/usr/bin/env python3
"""Reference reader for the theme exported by Quickshell Island.

Shows how a companion app should load the theme (format: docs/THEME.md):
start from built-in defaults, overlay whatever the file provides, and keep
working when the file is missing, unreadable or from a newer format version.

Run it to print the resolved theme:  python3 examples/read_theme.py
"""
import copy
import json
import os

SUPPORTED_VERSION = 1

# Used as-is when the shell has never run, and for any field the file lacks
DEFAULTS = {
    "version": SUPPORTED_VERSION,
    "scheme": "dark",
    "colors": {
        "background": "#000000",
        "surface": "#1c1c1e",
        "surfaceRaised": "#2c2c2e",
        "textPrimary": "#ffffff",
        "textSecondary": "#98989d",
        "textTertiary": "#636366",
        "onAccent": "#ffffff",
        "accent": "#0a84ff",
        "success": "#30d158",
        "warning": "#ff9f0a",
        "danger": "#ff453a",
        "palette": {},
    },
    "fonts": {
        "families": ["sans-serif"],
        "displayFamilies": ["sans-serif"],
    },
    "radius": {"small": 6, "medium": 10, "large": 14},
    "scale": {"ui": 1.0, "font": 1.0},
}


def theme_path():
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config_home, "quickshell-island", "theme.json")


def merge(defaults, loaded):
    """Overlay `loaded` on `defaults`, section by section.

    Unknown fields are kept, so a newer file with extra fields still loads.
    A field with the wrong shape (for example a string where a section is
    expected) is ignored and the default is used.
    """
    result = copy.deepcopy(defaults)
    for key, value in loaded.items():
        default = defaults.get(key)
        if isinstance(default, dict):
            if isinstance(value, dict):
                result[key] = merge(default, value)
        else:
            result[key] = value
    return result


def load_theme(path=None):
    """Return the theme as a dict. Never raises; falls back to DEFAULTS."""
    try:
        with open(path or theme_path(), encoding="utf-8") as f:
            loaded = json.load(f)
    except (OSError, ValueError):
        return merge(DEFAULTS, {})
    if not isinstance(loaded, dict):
        return merge(DEFAULTS, {})
    version = loaded.get("version")
    # A higher version means fields were removed or changed meaning
    if not isinstance(version, int) or version > SUPPORTED_VERSION:
        return merge(DEFAULTS, {})
    return merge(DEFAULTS, loaded)


def scaled(theme, px):
    """A size in pixels at the user's UI scale, as the shell's Theme.px does."""
    return round(px * theme["scale"]["ui"])


def font_scaled(theme, px):
    """A font size in pixels, as the shell's Theme.fontPx does."""
    return max(8, round(px * theme["scale"]["font"] * theme["scale"]["ui"]))


if __name__ == "__main__":
    theme = load_theme()
    print(json.dumps(theme, indent=2))
    print(f"\n12px text renders at {font_scaled(theme, 12)}px; a 40px row at {scaled(theme, 40)}px")
