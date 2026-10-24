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

Open it with `SettingsService.requestOpenSettings(tab)`. Its open state and position are `SettingsService.windowOpen`, `windowX` and `windowY`.
