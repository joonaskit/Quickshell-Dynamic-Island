# Quickshell Island

QML desktop shell for KDE Plasma (Wayland), built with Quickshell: a morphing top "island" bar plus a dock and app launcher. See README.md for features and requirements.

## Layout

- `shell.qml` is the entry point. It creates `IslandWindow` and `DockWindow` per screen and registers the `launcher` IPC handler.
- `services/*Service.qml` files are singletons that own state and talk to the system. Views bind to them and hold no system logic.
- `qmldir` registers every singleton and component. Add new QML files there. Files in subfolders (e.g. `dock/`) must `import ".."` to see the root types.
- `services/Theme.qml` holds colors, sizes and scale. Use it instead of hardcoding values.
- `scripts/` holds the Python helpers (`kwin_window_tracker.py`, `hardware_stats.py`, `devices.py`, `audio_*.py`, `downloads_tracker.py`, `clipboard_tracker.py`, `shortcuts.py`, `activities_bridge.py`) that feed data to the services. `scripts/kwin_script.js` runs inside KWin, loaded by the tracker from its own directory.
- `dock/` holds the dock (`Dock*.qml`, including `DockService`).
- `clipboard/` holds the clipboard history window. `ClipboardService` fills it from `scripts/clipboard_tracker.py`, and the history logic is in `services/clipboardHistory.js`. History stays in memory only, so never write it to disk. The one exception is copied images: the tracker saves them under `$XDG_RUNTIME_DIR` (tmpfs), deletes them when entries go, and wipes the folder when it starts and stops.
- `ActivityService` runs `scripts/activities_bridge.py`, the D-Bus API (`org.quickshell.IslandActivities`) that lets other apps show progress in the island. The validation, limits and ordering live in `scripts/activities_core.py` (no D-Bus), tested by `tests/test_activities_core.py`. The API is documented in `docs/ACTIVITIES_API.md`, so update that when the API changes. `examples/` holds the reference clients and `activity_tester.py`, a window of buttons for trying every scenario.
- `install.sh` is the installer (dependency check, clone or update, default config, autostart, `--import`, `--uninstall`), tested by `tests/test_install.py`. Every change it makes goes through `act`, so `--dry-run` stays accurate: a new step must use it. It never runs `sudo` without a typed yes, and never overwrites the config files.
- `onboarding/` holds the welcome guide: `OnboardingWindow` (one centred overlay window on the first screen, created in `shell.qml`) and one `Onboarding*.qml` page per step. `OnboardingService` holds its state and opens it on a new install, which is when `SettingsService.onboardingVersion` is below `onboardingCurrent`. A `settings.json` without the key counts as done, so existing users are not shown it. Raise `onboardingCurrent` only to show the guide to everyone again.
- `scripts/settings_backup.py` exports the three config files to one file and imports them (`./run.sh --export` / `--import`), tested by `tests/test_settings_backup.py`. `BackupService` runs it for the Backup section of the About settings page. After an import the shell must re-read the files: `SettingsService.reloadFromDisk` and `DockService.reloadConfig`, or the `config reload` IPC call. A new setting that belongs to one machine (a credential, a device id) goes in the script's `PRIVATE_KEYS`. The format is documented in `docs/CONFIG_EXPORT.md`, so update that when it changes.
- `deps.json` lists every external tool, Python module and D-Bus service the shell uses, with the features each one supports and its package name per distro. `scripts/check_deps.py` (`./run.sh --check`) checks them, tested by `tests/test_check_deps.py`. Add an entry there when a feature starts using a new tool.
- `quicksettings/` holds the quick-settings popups, selectors and sliders.
- `services/` holds the `*Service.qml` singletons and `Theme.qml`.
- `island/` holds the island window, pills, clusters, views and settings UI.
- `island/StatusIconRegistry.qml` lists the top-right status icons in default order. A new icon needs an entry there and a button component in `TopRightStatusCluster.qml` under the same id (`iconComponents`, `isIconShown`). The user's order is `statusIconOrder` in `settings.json`.
- `components/` holds small shared pieces (`SvgIcon`, `HiddenElementGlow`, `AudioVisualizer`, `BatteryIndicator`).
- `docs/ANIMATION_CATALOGUE.md` documents the animations.

## Running

- Quickshell hot-reloads on save for most QML changes, but not for everything. Icon changes (e.g. `SvgIcon`) do not reload, so the user must kill and start the process again (`./run.sh -k`, then `./run.sh`). Tell the user when a change needs this. If it has crashed, the user restarts it too.
- `./run.sh` starts it. Other flags: `-l` toggles the launcher, `-k` kills it, `-d` runs it as a daemon.
- There is no test suite. Changes are verified by hand in the running shell.

## Window and app matching

- `DockService.findToplevels` matches windows to apps. When a desktop entry declares `StartupWMClass`, matching must be exact.
- Do not add substring or fuzzy matching for such apps. It made the Vivaldi launcher entry match Vivaldi PWA windows, so launching Vivaldi focused the PWA.
- Windows come from two sources, Wayland toplevels and the KWin script. `getMergedWindows` combines them.

## Config files

- `settings.json` and `dock_pinned.json` are the user's live config and are gitignored. Never overwrite or commit them.
- Put new default keys in the `.example` files.

## Git

- Commit only when the user asks.
- Keep messages concise: a short capitalized summary of the work done, with no prefixes and no body unless needed. For example: "Fix app launcher window matching".
