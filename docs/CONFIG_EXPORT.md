# Configuration export format

`scripts/settings_backup.py` (`./run.sh --export` and `--import`, and the Backup section of the About settings page) writes and reads this file. It is one JSON document.

```json
{
  "format": "quickshell-island-config",
  "version": 1,
  "shellVersion": "v0.1.0-alpha.2-21-g9c78bad",
  "exportedAt": "2026-10-12T17:35:33+03:00",
  "sections": {
    "settings": { "uiScale": 1.0, "use24Hour": true },
    "dock": [ { "id": "dolphin", "name": "Files", "desktopFile": "org.kde.dolphin.desktop" } ],
    "usage": { "org.kde.dolphin": { "count": 3, "last": 1700000000000 } }
  }
}
```

| Field | Meaning |
| --- | --- |
| `format` | Always `quickshell-island-config`. Anything else is refused |
| `version` | The format version, a whole number. This document describes version 1 |
| `shellVersion` | `git describe` of the shell that made the export, or empty. For information only |
| `exportedAt` | When it was made, ISO 8601 with a time zone. For information only |
| `sections` | The parts of the configuration. Every section is optional, but one must be present |

## Sections

| Section | File it holds | Shape | In an export by default |
| --- | --- | --- | --- |
| `settings` | `settings.json` | An object of setting keys | Yes |
| `dock` | `dock_pinned.json` | A list of pinned apps, each an object with a non-empty string `id` | Yes |
| `usage` | `launcher_usage.json` | An object of app key to `{ "count": number, "last": number }` | No, only with `--usage` |

The `settings` section leaves out the keys that belong to one machine (`hueBridgeIp`, `hueAppKey`, `hueLightId`, `kdeConnectDeviceId`) unless the export was made with `--with-secrets`.

## Import rules

- The whole file is validated first. If the JSON is malformed, the `format` is wrong, the `version` is not a whole number of at least 1, a section has the wrong shape or no known section is present, the import fails and no file is changed.
- A `version` higher than the importing shell knows is refused. A lower one is accepted. When the format changes, the importer converts older versions.
- Unknown top-level fields and unknown sections are ignored.
- Each imported section replaces its file as a whole. Sections that are not imported (not in the file, or not chosen with `--sections`) keep their current files.
- The `settings` section goes through the shell's normal loading (`SettingsService.applySettings`), so older key names are migrated, values are clamped, unknown keys are ignored and missing keys take their defaults.
- Machine-specific keys missing from the file keep the values the importing machine already has.
- Before writing, the files about to be replaced are copied to `$XDG_STATE_HOME/quickshell-island/backups/<time>/` (`~/.local/state` when the variable is unset).
- Pinned apps whose desktop file is not installed are still imported, and reported as a note.

## Implementation

- `scripts/settings_backup.py` writes and reads the file, tested by `tests/test_settings_backup.py`. `services/BackupService.qml` runs it for the Backup section of the About settings page.
- After an import the running shell must re-read the files: `SettingsService.reloadFromDisk` and `DockService.reloadConfig`, or the `config reload` IPC call.
- The machine-specific keys are `PRIVATE_KEYS` in the script. A new one goes there and in the list above.
