#!/usr/bin/env python3
"""Apply the shell's theme to KDE as a colour scheme (see docs/KDE_THEME.md).

Usage:
  kde_colors.py apply <theme-json> [gray|black]   Write the scheme and make it the active one
  kde_colors.py restore                           Go back to the scheme that was active before

<theme-json> is the document the shell writes to theme.json (docs/THEME.md).
gray (the default) builds the windows on the theme's surface colour, as
Filehouse does; black builds them on its background, black on the dark scheme.

The scheme is written to $XDG_DATA_HOME/color-schemes and applied with
plasma-apply-colorscheme. That tool does nothing when asked for the scheme
that is already active, so updates alternate between two names. The scheme
that was active before is kept in $XDG_STATE_HOME/quickshell-island.

Prints one word for the shell: "applied", "unchanged", "overridden" (the user
picked another scheme in System Settings, so the shell's is no longer applied),
"restored" or "nothing". Exits 3 for "overridden" and 1 on an error.
"""
import json
import os
import subprocess
import sys
import tempfile

SCHEME_NAMES = ("QuickshellIsland", "QuickshellIslandAlt")
DISPLAY_NAME = "Quickshell Island"
# What Plasma uses when kdeglobals names no scheme
DEFAULT_SCHEME = "BreezeLight"
APPLY_TOOL = "plasma-apply-colorscheme"
BASES = ("gray", "black")

# For the gray base, as Filehouse builds its window: its cards and the raised controls on
# them are the surface with this much of the text colour mixed in
CARD_SHARE = 0.04
RAISED_SHARE = 0.10

DEFAULT_COLORS = {
    "dark": {
        "background": "#000000", "surface": "#1c1c1e", "surfaceRaised": "#2c2c2e",
        "textPrimary": "#ffffff", "textSecondary": "#98989d", "textTertiary": "#636366",
        "accent": "#0a84ff", "onAccent": "#ffffff",
        "success": "#30d158", "warning": "#ff9f0a", "danger": "#ff453a",
        "palette": {"blue": "#0a84ff", "purple": "#bf5af2"},
    },
    "light": {
        "background": "#faf6ef", "surface": "#f1ebe1", "surfaceRaised": "#e7dfd2",
        "textPrimary": "#221f1a", "textSecondary": "#575147", "textTertiary": "#787166",
        "accent": "#0a84ff", "onAccent": "#ffffff",
        "success": "#30d158", "warning": "#ff9f0a", "danger": "#ff453a",
        "palette": {"blue": "#0a84ff", "purple": "#bf5af2"},
    },
}


class SchemeError(Exception):
    pass


# Colours

def parse_color(value):
    """"#rrggbb" -> (r, g, b), or None for anything else."""
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        return None
    try:
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
    except ValueError:
        return None


def mix(a, b, amount):
    """`a` moved `amount` (0 to 1) of the way towards `b`."""
    return tuple(round(x + (y - x) * amount) for x, y in zip(a, b, strict=True))


def rgb(color):
    return "%d,%d,%d" % color


def resolve_colors(theme):
    """The theme's colours as (r, g, b), with defaults for anything missing or invalid."""
    theme = theme if isinstance(theme, dict) else {}
    scheme = "light" if theme.get("scheme") == "light" else "dark"
    defaults = DEFAULT_COLORS[scheme]
    given = theme.get("colors") if isinstance(theme.get("colors"), dict) else {}
    palette = given.get("palette") if isinstance(given.get("palette"), dict) else {}

    colors = {}
    for key, default in defaults.items():
        if key == "palette":
            continue
        colors[key] = parse_color(given.get(key)) or parse_color(default)
    for key in ("blue", "purple"):
        colors[key] = parse_color(palette.get(key)) or parse_color(defaults["palette"][key])
    return scheme, colors


# Building the scheme

def section(background, alternate, c, foreground=None, inactive=None):
    """One [Colors:*] group. `c` is the resolved colours."""
    foreground = foreground or c["textPrimary"]
    return {
        "BackgroundNormal": background,
        "BackgroundAlternate": alternate,
        "ForegroundNormal": foreground,
        "ForegroundInactive": inactive or c["textSecondary"],
        "ForegroundActive": c["accent"],
        "ForegroundLink": c["blue"],
        "ForegroundVisited": c["purple"],
        "ForegroundNegative": c["danger"],
        "ForegroundNeutral": c["warning"],
        "ForegroundPositive": c["success"],
        "DecorationFocus": c["accent"],
        "DecorationHover": c["accent"],
    }


def layers(c, base):
    """(window, card, raised, dim) for a base: what windows, lists and headers are drawn
    on, the cards and menus on them, the controls, and inactive titlebars."""
    if base == "black":
        # The shell's own layers, with lists and text fields on the black background
        return c["background"], c["surface"], c["surfaceRaised"], mix(c["surface"], c["background"], 0.5)
    window = c["surface"]
    return (window, mix(window, c["textPrimary"], CARD_SHARE), mix(window, c["textPrimary"], RAISED_SHARE),
            mix(window, c["background"], 0.25))


def build_groups(theme, name, base="gray"):
    """The scheme as {group: {key: value}}, in file order."""
    scheme, c = resolve_colors(theme)
    bg = c["background"]
    window, card, raised, dim = layers(c, base)

    selection = section(c["accent"], mix(c["accent"], bg, 0.4), c,
                        foreground=c["onAccent"], inactive=mix(c["onAccent"], c["accent"], 0.3))
    # Status colours on an accent fill are moved towards the text colour so they stay readable
    for key in ("ForegroundNegative", "ForegroundNeutral", "ForegroundPositive", "ForegroundLink", "ForegroundVisited"):
        selection[key] = mix(selection[key], c["onAccent"], 0.4)
    selection["ForegroundActive"] = c["onAccent"]

    if base == "black":
        colors = {
            # Lists and text fields: the shell's background, the lowest layer, as on Breeze
            "Colors:View": section(window, mix(window, card, 0.5), c),
            "Colors:Window": section(card, raised, c),
            "Colors:Header": section(card, window, c),
            "Colors:Header][Inactive": section(dim, card, c, inactive=c["textTertiary"]),
            "Colors:Tooltip": section(raised, card, c),
            "Colors:Complementary": section(window, card, c),
        }
        titlebar = card
    else:
        # Lists sit on the window itself, as Filehouse's do, with menus and tooltips as cards
        colors = {
            "Colors:View": section(window, card, c),
            "Colors:Window": section(window, card, c),
            "Colors:Header": section(window, card, c),
            "Colors:Header][Inactive": section(dim, window, c, inactive=c["textTertiary"]),
            "Colors:Tooltip": section(card, window, c),
            "Colors:Complementary": section(card, window, c),
        }
        titlebar = window
    colors["Colors:Button"] = section(raised, mix(raised, c["accent"], 0.3), c)
    colors["Colors:Selection"] = selection

    groups = {
        "ColorEffects:Disabled": {
            "Color": bg, "ColorAmount": "0", "ColorEffect": "0",
            "ContrastAmount": "0.65", "ContrastEffect": "1",
            "IntensityAmount": "0.1", "IntensityEffect": "2",
        },
        "ColorEffects:Inactive": {
            "ChangeSelectionColor": "true", "Color": bg, "ColorAmount": "0.025",
            "ColorEffect": "2", "ContrastAmount": "0.1", "ContrastEffect": "2",
            "Enable": "false", "IntensityAmount": "0", "IntensityEffect": "0",
        },
    }
    for key in sorted(colors):
        groups[key] = colors[key]
    groups["General"] = {
        "ColorScheme": name,
        "Name": DISPLAY_NAME,
        "shadeSortColumn": "true",
    }
    groups["KDE"] = {"contrast": "4"}
    # Titlebars, for decorations that take their colours from the scheme (Breeze does)
    groups["WM"] = {
        "activeBackground": titlebar,
        "activeBlend": c["textPrimary"],
        "activeForeground": c["textPrimary"],
        "inactiveBackground": dim,
        "inactiveBlend": c["textTertiary"],
        "inactiveForeground": c["textTertiary"],
    }
    return scheme, groups


def build_scheme(theme, name, base="gray"):
    """The .colors file for `theme` (the theme.json document) on a base, as text."""
    scheme, groups = build_groups(theme, name, base)
    lines = [
        "# Generated by Quickshell Island from its %s theme on the %s base. It is rewritten when" % (scheme, base),
        "# the shell's theme changes: change the colours in the shell's settings.",
    ]
    for group, values in groups.items():
        lines.append("")
        lines.append("[%s]" % group)
        for key, value in values.items():
            lines.append("%s=%s" % (key, rgb(value) if isinstance(value, tuple) else value))
    return "\n".join(lines) + "\n"


# Files

def data_home():
    return os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")


def config_home():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")


def scheme_path(name):
    return os.path.join(data_home(), "color-schemes", name + ".colors")


def state_path():
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(state, "quickshell-island", "kde-colors.json")


def read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except (OSError, UnicodeDecodeError):
        return None


def write_text(path, text):
    """Replace `path` atomically, so KDE never reads a partial scheme."""
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".quickshell-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def remove(path):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def current_scheme(kdeglobals=None):
    """The ColorScheme in kdeglobals' [General] group, or "" when it names none."""
    text = read_text(kdeglobals or os.path.join(config_home(), "kdeglobals")) or ""
    group = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("["):
            group = line
        elif group == "[General]" and line.startswith("ColorScheme="):
            return line[len("ColorScheme="):].strip()
    return ""


def load_state():
    """The saved state, or None when the shell's scheme has not been applied."""
    text = read_text(state_path())
    if text is None:
        return None
    try:
        state = json.loads(text)
    except ValueError:
        return {"previous": ""}
    if not isinstance(state, dict) or not isinstance(state.get("previous"), str):
        return {"previous": ""}
    return state


def save_state(state):
    write_text(state_path(), json.dumps(state, indent=2) + "\n")


def run_apply_tool(name):
    """Make `name` the active scheme. Raises SchemeError when the tool fails."""
    try:
        result = subprocess.run([APPLY_TOOL, name], capture_output=True, text=True, timeout=60)
    except FileNotFoundError:
        raise SchemeError(APPLY_TOOL + " is not installed") from None
    except subprocess.TimeoutExpired:
        raise SchemeError(APPLY_TOOL + " did not finish") from None
    if result.returncode != 0:
        raise SchemeError((result.stderr or result.stdout).strip() or APPLY_TOOL + " failed")


# Commands

def apply(theme, base="gray", run=run_apply_tool):
    """Write the scheme for `theme` on a base and make it active. Returns the word to print."""
    current = current_scheme()
    state = load_state()
    if state is not None and current not in SCHEME_NAMES:
        # Picked in System Settings since: that choice wins, and the shell stops applying its own
        for name in SCHEME_NAMES:
            remove(scheme_path(name))
        remove(state_path())
        return "overridden"

    if current in SCHEME_NAMES and read_text(scheme_path(current)) == build_scheme(theme, current, base):
        return "unchanged"

    if state is None:
        save_state({"previous": "" if current in SCHEME_NAMES else current})

    target = SCHEME_NAMES[1] if current == SCHEME_NAMES[0] else SCHEME_NAMES[0]
    write_text(scheme_path(target), build_scheme(theme, target, base))
    try:
        run(target)
    except SchemeError:
        remove(scheme_path(target))
        if state is None:
            remove(state_path())
        raise
    for name in SCHEME_NAMES:
        if name != target:
            remove(scheme_path(name))
    return "applied"


def restore(run=run_apply_tool):
    """Go back to the scheme from before, and remove the shell's. Returns the word to print."""
    state = load_state()
    current = current_scheme()
    existing = [name for name in SCHEME_NAMES if os.path.exists(scheme_path(name))]
    if state is None and current not in SCHEME_NAMES and not existing:
        return "nothing"

    if current in SCHEME_NAMES:
        previous = (state or {}).get("previous") or DEFAULT_SCHEME
        try:
            run(previous)
        except SchemeError:
            # The scheme from before may have been deleted since
            if previous == DEFAULT_SCHEME:
                raise
            run(DEFAULT_SCHEME)
    for name in SCHEME_NAMES:
        remove(scheme_path(name))
    remove(state_path())
    return "restored"


def main(argv):
    try:
        if len(argv) in (3, 4) and argv[1] == "apply" and (len(argv) == 3 or argv[3] in BASES):
            result = apply(json.loads(argv[2]), argv[3] if len(argv) == 4 else "gray")
        elif len(argv) == 2 and argv[1] == "restore":
            result = restore()
        else:
            sys.stderr.write("usage: kde_colors.py apply <theme-json> [gray|black] | restore\n")
            return 2
    except ValueError as e:
        sys.stderr.write("kde_colors.py: the theme is not valid JSON: %s\n" % e)
        return 1
    except (SchemeError, OSError) as e:
        sys.stderr.write("kde_colors.py: %s\n" % e)
        return 1
    print(result)
    return 3 if result == "overridden" else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
