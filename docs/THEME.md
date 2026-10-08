# Shared theme

The shell exports its theme (colors, fonts, corner radius and scale) to a file, so companion apps that run as separate processes can match its look. This document is the contract for that file.

## Decision

The theme is shared as a **JSON file written by the shell**.

- It works from any language and toolkit.
- Apps can read it at startup without the shell running, so an app keeps the last theme the shell wrote.
- A missing file is a normal case with an obvious answer: use built-in defaults.

The other options considered in #22 were a shared QML module (only helps QML apps, and couples projects by path), a D-Bus interface (needs the shell running) and following the system theme (the shell has its own look). A D-Bus signal or a QML wrapper can be added on top of the file later without changing it.

## Location

```
$XDG_CONFIG_HOME/quickshell-island/theme.json
```

`~/.config` is used when `XDG_CONFIG_HOME` is unset or empty.

The shell owns this file and overwrites it. It is not a place for user edits: change the theme through the shell's settings.

## Format

```json
{
  "version": 1,
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
    "palette": {
      "green": "#30d158",
      "blue": "#0a84ff",
      "orange": "#ff9f0a",
      "yellow": "#ffd60a",
      "red": "#ff453a",
      "purple": "#bf5af2",
      "cyan": "#64d2ff",
      "indigo": "#5e5ce6"
    }
  },
  "fonts": {
    "families": ["Cantarell", "Noto Sans", "Liberation Sans", "sans-serif"],
    "displayFamilies": ["Cantarell", "Noto Sans", "Liberation Sans", "sans-serif"]
  },
  "radius": { "small": 6, "medium": 10, "large": 14 },
  "scale": { "ui": 1.0, "font": 1.0 }
}
```

| Field | Meaning |
| --- | --- |
| `version` | Format version, an integer. See Versioning |
| `scheme` | `"dark"` or `"light"`. Only `"dark"` is written today |
| `colors.background` | Window background, the darkest layer |
| `colors.surface` | Cards and panels on top of the background |
| `colors.surfaceRaised` | Hovered cards, and controls on top of a surface |
| `colors.textPrimary`, `textSecondary`, `textTertiary` | Text, from most to least prominent |
| `colors.onAccent` | Text and icons on top of `accent`, `success`, `warning` or `danger` fills |
| `colors.accent` | Selection, focus and primary actions |
| `colors.success`, `warning`, `danger` | Status colors. Use these rather than picking from `palette` |
| `colors.palette` | The full set of accent colors, for categories and decoration |
| `fonts.families` | Font families for text, in order of preference |
| `fonts.displayFamilies` | Font families for large or numeric text such as clocks and titles |
| `radius.small`, `medium`, `large` | Corner radii in unscaled pixels: small controls, buttons and rows, cards |
| `scale.ui` | The user's UI scale, `0.80` to `1.25` |
| `scale.font` | The user's extra font scale, `0.85` to `1.25` |

Colors are `#rrggbb` strings.

### Applying the scale

Sizes in the file, and sizes an app defines itself, are unscaled. Multiply them the way the shell does:

- A size in pixels: `round(px * scale.ui)`
- A font size in pixels: `max(8, round(px * scale.font * scale.ui))`

## Rules for readers

1. **Start from built-in defaults**, then overlay the file. The defaults should be a complete theme, so the app works when the shell has never run.
2. **A missing or unreadable file is not an error.** Use the defaults.
3. **Ignore fields you do not know.** New fields can appear without a version bump.
4. **Do not require every field.** Fall back to your default for any field that is missing or has the wrong type.
5. **Check `version`.** If it is higher than the version you support, or missing, use your defaults.

`examples/read_theme.py` is a reference reader that follows these rules. Run it to print the resolved theme:

```
python3 examples/read_theme.py
```

## Updates

The shell writes the file at startup and again whenever the theme or the scale settings change. It replaces the file atomically (write to a temporary file, then rename), so a reader never sees a partial file, and it leaves the file untouched when nothing changed.

Reading the file once at startup is enough for a first version of an app. To follow changes while running, watch the **directory** for the file being replaced: because of the atomic rename, a watch on the file itself stops firing after the first update.

## Versioning

`version` is bumped only when a field is removed or changes meaning. Adding a field does not bump it. A reader that supports version N can therefore read any version N file, however many fields were added since.

## In the shell

- `services/Theme.qml` is the single source of truth for the exported values.
- `services/themeExport.js` builds the document (tested in `tests/tst_themeExport.qml`).
- `services/ThemeExportService.qml` maps `Theme.qml` to the document and triggers the write.
- `scripts/write_theme.py` writes the file (tested in `tests/test_write_theme.py`).

To export a new value: add it to `Theme.qml`, to the map in `ThemeExportService.qml`, to `build` in `themeExport.js`, to this document and to the defaults in `examples/read_theme.py`.

Not everything in the shell uses `Theme.qml` yet. Translucent overlays (hover highlights, dividers, borders) are still written inline as `Qt.rgba(...)` in many files. They are derived from white at a low opacity and are not exported.
