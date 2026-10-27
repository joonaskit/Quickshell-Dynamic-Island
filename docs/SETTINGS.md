# Settings

How settings are stored and how to add one. For what the user sees, see the settings window itself.

## Files

`settings.json` and `dock_pinned.json` are the user's live config and are gitignored. Defaults live in `settings.json.example` and `dock_pinned.json.example`, so new default keys go there.

## Adding a setting

A new `settings.json` key needs five things:

1. Its default in `settings.json.example`.
2. A property in `services/SettingsService.qml`.
3. A load line in `applySettings`.
4. A reset in `resetDefaults`.
5. An entry in `saveSettings`.

`tests/test_settings_keys.py` checks all five. Keys handled differently on purpose go in its allow-lists.

A setting that belongs to one machine (a credential, a device id) also goes in `PRIVATE_KEYS` in `scripts/settings_backup.py`, so exports leave it out. List it in `docs/CONFIG_EXPORT.md` too.

## The settings window

`settings/SettingsWindow.qml` is a floating panel styled like the clipboard window, one per screen, shown on the active one. The pages and their controls are in `island/settings/`.

Open it with `SettingsService.requestOpenSettings(tab, section)`, or `quickshell ipc call settings open <tab> <section>`. `tab` is a name from the window's tab list and `section` the `key` of a `SettingsSection` on it; the window scrolls to that section and outlines it for a moment. Either can be empty. Its open state and position are `SettingsService.windowOpen`, `windowX` and `windowY`.

Menus link to the settings that change them: the window controls and virtual desktops menus open Top bar at `pills`, and the gear under a status icon popup opens `statusIcons` or `optionalIcons`. Give a new section a `key` when something should link to it.

## Search

The search box shows every row whose title, description or `keywords` holds all the typed words, in any order, ignoring case and hyphens (`services/settingsSearch.js`, tested by `tests/tst_settingsSearch.qml`). Each page's matches come under its name. Give a row `keywords` for other words people may search with: what the feature used to be called, or what other desktops call it.

## Pages

- **Appearance**: colours, screens, corners, pill style, scale and fonts.
- **Top bar**: a sketch of the bar whose parts link to their sections (`TopBarDiagram.qml`), when the full-width bar shows and hiding it, the side pills, the status icons and the optional icons.
- **Island**: what the compact island shows, the expanded island cards and the clock.
- **Dock**, **Launcher**, **Shortcuts** and **About**.

Put a setting on the page for the part of the screen it changes.

## Choices over several keys

A setting with a sub-setting that only applies while it is on (show and auto-hide, show and keep shown) is one `SettingChoice` row, not a toggle and a sub-toggle. `SettingsService.pairValue(key, subKey)` reads the pair as `"off"`, `"on"` or `"sub"`, and `setPair` saves it. The top bar mode is the same over `morphToTopBarWhenMaximized` and `alwaysTopBar` (`topBarMode`, `setTopBarMode`). The keys stay separate in `settings.json`. The mapping is in `services/settingChoices.js`, tested by `tests/tst_settingChoices.qml`.
