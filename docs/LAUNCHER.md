# Launcher search

The app launcher (`dock/DockAppPicker.qml`) searches apps, and around that list it can show three extras. The app list and its order are the same with or without them.

## Calculator, unit conversion and web search shortcuts

Pure functions in `services/launcherExtras.js`, tested by `tests/tst_launcherExtras.qml`. The answer appears as a card above the apps.

- Expressions go through the parser in `launcherExtras.js`, never `eval`.
- Shortcut URLs must be http or https.

## KDE System Settings pages

The `launcherSettingsSearch` setting, on by default. Matching pages are listed in a column that widens the launcher beside the apps.

- The pages are hidden `kcm_*.desktop` entries. `SettingsPagesService` reads them once per launcher open from `scripts/settings_pages.py` (tested by `tests/test_settings_pages.py`).
- `matchSettingsPages` in `launcherExtras.js` ranks them.
- Tab moves focus into the column (`settingsFocused` in `DockAppPicker.qml`). Enter opens its first page when no app matched.

## Files

Typing `f name` searches files. Off by default.

- `FileSearchService` runs `filehouse --search` from the companion repo (`../filehouse`; the output format is in its `ARCHITECTURE.md` under Search) and reads its JSON lines with `LauncherExtras.parseFileLine`.
- The search itself lives in Filehouse. This repo only runs it and shows the results.
- The files take the place of the app list only while the key is typed.
