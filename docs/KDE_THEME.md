# KDE colour scheme

The **Apply to KDE Apps** setting (Settings → Appearance → Colors) makes KDE apps and window titlebars use the shell's colours. It is off by default. Turning it off restores the scheme that was active before.

## Decision

The shell's theme is applied as a generated **KDE colour scheme**, made active with `plasma-apply-colorscheme`.

KDE has no single setting for titlebar or app colours: both come from the active colour scheme, so a scheme is the one route that covers both. The other options considered in #56:

| Route | Why not |
| --- | --- |
| `kwinrc` and decoration settings | They set the button layout and border size, not colours |
| A custom Aurorae theme | Changes titlebars only, and is a lot of work for SVG artwork. Could come later to match corner radii |
| Frameless windows with their own titlebar | Only for apps that opt in |

### What it does not cover

- **Aurorae decorations.** Breeze takes titlebar colours from the scheme (`[WM]` and `[Colors:Header]`). Aurorae themes, such as most decorations on the KDE Store, draw titlebars from their own SVG files and set their title text colours in their own config, so their titlebars mostly stay as they are. App colours still change.
- **GTK apps.** They do not read KDE colour schemes.
- **KDE's accent colour.** When an accent is set in System Settings → Colours (including one taken from the wallpaper), KDE puts it over the scheme's selection colour. The shell leaves that setting alone.
- **Fonts, corner radii and shadows.** They stay as KDE sets them.

The scheme applies to every KDE app and follows the shell's Appearance setting: a dark shell makes the apps dark.

## How it works

`services/KdeThemeService.qml` runs `scripts/kde_colors.py` (tested in `tests/test_kde_colors.py`):

- **Setting on:** `kde_colors.py apply <theme>` with the theme document from `ThemeExportService` (the same JSON as `theme.json`, see [THEME.md](THEME.md)). It runs again when the colours or the Appearance setting change, 1.5 seconds after the last change, since applying a scheme repaints every open KDE app. Scale, font and corner changes leave the scheme alone.
- **Setting off:** `kde_colors.py restore`. It also runs at startup when the setting is off, so a scheme left by a crash is cleaned up. It does nothing when the shell's scheme was never applied.
- **Uninstall:** `install.sh --uninstall` runs `restore`.

### Files

| File | Contents |
| --- | --- |
| `$XDG_DATA_HOME/color-schemes/QuickshellIsland.colors` or `QuickshellIslandAlt.colors` | The scheme. Only one exists at a time. It is listed in System Settings as "Quickshell Island" |
| `$XDG_STATE_HOME/quickshell-island/kde-colors.json` | `{"previous": "<scheme>"}`: the scheme to restore. Present only while the shell's scheme is applied |

`~/.local/share` and `~/.local/state` are used when the variables are unset.

`plasma-apply-colorscheme` does nothing when asked for the scheme that is already active, so each update writes the other of the two names, applies it and deletes the first one.

### The user picks another scheme

Before each update the script checks the active scheme in `kdeglobals`. If it is no longer one of the shell's, the user chose another one in System Settings. That choice wins: the script removes its files and state and prints `overridden`, and the shell turns the setting off.

If the scheme to restore no longer exists, `restore` falls back to Breeze Light, which is also Plasma's own default.

## Colour mapping

The **KDE Window Background** setting (`kdeColorBase` in `settings.json`) picks what windows are built on in the dark appearance:

- **Gray** (the default) builds them on the theme's `surface`, as Filehouse does. Pitch black suits the island and the top bar, but is harsh behind a whole window. Cards, menus and tooltips are the surface with 4% of `textPrimary` mixed in, and buttons with 10%, the same layers as Filehouse's `style.layer`.
- **Black** puts lists and text fields on the theme's `background` (black), with windows on `surface` and buttons on `surfaceRaised`, the shell's own layers.

The light appearance always uses Gray, since it has no black to soften. The script takes the base as its last argument: `kde_colors.py apply <theme> gray|black`.

| KDE group | Gray | Black |
| --- | --- | --- |
| `Colors:View` (lists, text fields) | `surface` | `background` |
| `Colors:Window` | `surface` | `surface` |
| `Colors:Header` | `surface` | `surface` |
| `Colors:Button` | surface + 10% text | `surfaceRaised` |
| `Colors:Tooltip` | surface + 4% text | `surfaceRaised` |
| `Colors:Complementary` | surface + 4% text | `background` |
| `Colors:Selection` | `accent`, with `onAccent` text | the same |
| `WM` (titlebars) | `surface` | `surface` |

Inactive headers and titlebars are a little darker, mixed towards `background`, with `textTertiary` text.

In every group the text is `textPrimary` and `textSecondary`, focus and hover use `accent`, links use the palette's `blue` and `purple`, and the negative, neutral and positive colours are `danger`, `warning` and `success`.

Selection stays a solid `accent` rather than Filehouse's faint accent tint, because KDE also uses it to fill checkboxes, progress bars and sliders.
