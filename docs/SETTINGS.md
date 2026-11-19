# Settings

How settings are stored and how to add one. For what the user sees, see the settings window itself.

## Files

The user's config files live in `SettingsService.configDir`: `$ISLAND_CONFIG_DIR`, else `~/.config/quickshell-island/`, beside `theme.json`. They are `settings.json`, the dock's `dock_pinned.json`, the dial's `dial_pinned.json` and the launcher's `launcher_usage.json`. Defaults live in `settings.json.example` and `dock_pinned.json.example` in the shell, so new default keys go there.

Older versions kept those files in the shell folder. `run.sh` moves them to the config folder before each start, once: a file already in the config folder wins, and the old one is left where it was. It also creates the folder, which matters because a file watch cannot be set on a folder that does not exist yet. Set `ISLAND_CONFIG_DIR` to give a checkout config of its own, for example `ISLAND_CONFIG_DIR="$PWD" ./run.sh` for a development checkout that should not share the installed shell's settings. `theme.json` stays in `~/.config/quickshell-island/` either way, since companion apps read it there.

`SettingsService` reads `settings.json` through `WatchedFile` (`components/WatchedFile.qml`), at start and again whenever the file changes, so a hand edit or an import applies at once. Its own saves (`saveSettings`, 250 ms after a change) come back as changes and are skipped by their text (`lastWritten`). A change from elsewhere is applied without being written back, so a hand-edited file keeps its layout; a file that lacks keys (an export from an older version) first resets the settings to their defaults, so those keys do too. A file that does not parse is ignored and the current settings kept, and an empty one is taken for an editor halfway through saving.

## Adding a setting

A new `settings.json` key needs five things:

1. Its default in `settings.json.example`.
2. A property in `services/SettingsService.qml`.
3. A load line in `applySettings`.
4. A reset in `resetDefaults`.
5. An entry in `currentData`, which `saveSettings` writes.

`tests/test_settings_keys.py` checks all five. Keys handled differently on purpose go in its allow-lists.

A setting that belongs to one machine (a credential, a device id) also goes in `PRIVATE_KEYS` in `scripts/settings_backup.py`, so exports leave it out. List it in `docs/CONFIG_EXPORT.md` too.

## The settings window

`settings/SettingsWindow.qml` is a floating panel styled like the clipboard window, one per screen, shown on the active one. Its card and pages are built the first time it opens (`content`, through a `Loader`) and kept after; `requestOpenSettings` opens the window before asking for the tab and section, so they apply to the built card. The pages and their controls are in `island/settings/`.

Open it with `SettingsService.requestOpenSettings(tab, section)`, or `quickshell ipc call settings open <tab> <section>`. `tab` is a name from the window's tab list and `section` the `key` of a `SettingsSection` on it; the window scrolls to that section and outlines it for a moment. Either can be empty. Its open state and position are `SettingsService.windowOpen`, `windowX` and `windowY`.

Menus link to the settings that change them: the window controls and virtual desktops menus open Top bar at `pills`, and the gear under a status icon popup opens `statusIcons` or `optionalIcons`. Give a new section a `key` when something should link to it.

## Search

The search box shows every row whose title, description or `keywords` holds all the typed words, in any order, ignoring case and hyphens (`services/settingsSearch.js`, tested by `tests/tst_settingsSearch.qml`). Each page's matches come under its name. Give a row `keywords` for other words people may search with: what the feature used to be called, or what other desktops call it.

## Pages

- **Appearance**: colours, screens, corners, pill style, scale and fonts.
- **Top bar**: a sketch of the bar whose parts link to their sections (`TopBarDiagram.qml`), under niri a button for niri's defaults (see `NIRI.md`), when the full-width bar shows and hiding it, the side pills, the status icons and the optional icons.
- **Island**: what the compact island shows, the expanded island cards and the clock.
- **Dock** and **Launcher**.
- **Power**: battery behaviour, such as 60 Hz on battery.
- **Shortcuts**: KDE's global shortcuts, or under niri the shell's commands bound in niri's config, with a link to niri-settings for niri's other binds (`NiriShortcutsSettings.qml`, see `NIRI.md`).
- **About**.

Put a setting on the page for the part of the screen it changes.

## Choices over several keys

A setting with a sub-setting that only applies while it is on (show and auto-hide, show and keep shown) is one `SettingChoice` row, not a toggle and a sub-toggle. `SettingsService.pairValue(key, subKey)` reads the pair as `"off"`, `"on"` or `"sub"`, and `setPair` saves it. The top bar mode is the same over `morphToTopBarWhenMaximized` and `alwaysTopBar` (`topBarMode`, `setTopBarMode`). The keys stay separate in `settings.json`. The mapping is in `services/settingChoices.js`, tested by `tests/tst_settingChoices.qml`.
