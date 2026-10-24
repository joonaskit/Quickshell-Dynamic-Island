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
- `ActivityService` runs `scripts/activities_bridge.py`, the D-Bus API (`org.quickshell.IslandActivities`) that lets other apps show progress in the island. The validation, limits and ordering live in `scripts/activities_core.py` (no D-Bus), tested by `tests/test_activities_core.py`. The API is documented in `docs/ACTIVITIES_API.md`, so update that when the API changes. `examples/` holds the reference clients and `activity_tester.py`, a window of buttons for trying every scenario. `scripts/island_run.py` (`./run.sh --run`) wraps any command as an activity; its parsing is in `scripts/island_run_core.py`, tested by `tests/test_island_run_core.py`. It is started by the user, so `run.sh`'s `stop_helpers` must leave it alone. `install.sh` links it as `~/.local/bin/island-run` (so it resolves its imports with `realpath`) and removes only a link that points into the install.
- `install.sh` is the installer (dependency check, clone or update, default config, autostart, `--import`, `--uninstall`), tested by `tests/test_install.py`. Every change it makes goes through `act`, so `--dry-run` stays accurate: a new step must use it. It never runs `sudo` without a typed yes, and never overwrites the config files.
- `onboarding/` holds the welcome guide: `OnboardingWindow` (one centred overlay window on the first screen, created in `shell.qml`) and one `Onboarding*.qml` page per step. `OnboardingService` holds its state and opens it on a new install, which is when `SettingsService.onboardingVersion` is below `onboardingCurrent`. A `settings.json` without the key counts as done, so existing users are not shown it. Raise `onboardingCurrent` only to show the guide to everyone again.
- `scripts/settings_backup.py` exports the three config files to one file and imports them (`./run.sh --export` / `--import`), tested by `tests/test_settings_backup.py`. `BackupService` runs it for the Backup section of the About settings page. After an import the shell must re-read the files: `SettingsService.reloadFromDisk` and `DockService.reloadConfig`, or the `config reload` IPC call. A new setting that belongs to one machine (a credential, a device id) goes in the script's `PRIVATE_KEYS`. The format is documented in `docs/CONFIG_EXPORT.md`, so update that when it changes.
- The launcher's search extras (calculator, unit conversion, web search shortcuts) are pure functions in `services/launcherExtras.js`, tested by `tests/tst_launcherExtras.qml`. `dock/DockAppPicker.qml` shows the answer as a card above the apps and never reorders the app list. Expressions go through the parser there, never `eval`, and shortcut URLs must be http or https.
- The launcher's settings search lists the KDE System Settings pages in a column that widens the launcher beside the apps. The pages are hidden `kcm_*.desktop` entries, so `SettingsPagesService` reads them once per launcher open from `scripts/settings_pages.py` (tested by `tests/test_settings_pages.py`) and ranks them with `matchSettingsPages` in `services/launcherExtras.js`. The apps list and its order are untouched. Tab moves focus into the column (`settingsFocused` in `dock/DockAppPicker.qml`), and Enter opens its first page when no app matched. It is the `launcherSettingsSearch` setting, on by default.
- The launcher's file search (`f name`, off by default) is `FileSearchService`, which runs `filehouse --search` from the companion repo (`../filehouse`, format in its ARCHITECTURE.md under Search) and reads its JSON lines with `LauncherExtras.parseFileLine`. The search itself lives in Filehouse, so do not reimplement the walk here. The files take the place of the app list only while the key is typed.
- `HelperService` tracks the long-running helper scripts for the Health section of the About page (`island/settings/HealthSection.qml`). A service that starts a long-running script registers its `Process` with `HelperService.watch(id, name, proc)`. `scripts/helper_health.py` finds leftover helpers from an earlier run (its `LONG_RUNNING` list names the scripts to look for, so add a new long-running helper there), tested by `tests/test_helper_health.py`.
- `deps.json` lists every external tool, Python module and D-Bus service the shell uses, with the features each one supports and its package name per distro. `scripts/check_deps.py` (`./run.sh --check`) checks them, tested by `tests/test_check_deps.py`. Add an entry there when a feature starts using a new tool.
- `KdeThemeService` applies the shell's colours to KDE as a colour scheme while the `kdeColorScheme` setting is on, and restores the scheme from before when it is turned off. The scheme is built and applied by `scripts/kde_colors.py`, tested by `tests/test_kde_colors.py`, and `install.sh --uninstall` runs its `restore`. Documented in `docs/KDE_THEME.md`, so update that when the mapping changes.
- `quicksettings/` holds the quick-settings popups, selectors and sliders.
- `services/` holds the `*Service.qml` singletons and `Theme.qml`.
- `island/` holds the island window, pills, clusters and views. `island/settings/` holds the settings pages and controls.
- `settings/SettingsWindow.qml` is the settings window, a floating panel styled like the clipboard window (one per screen, shown on the active one). Open it with `SettingsService.requestOpenSettings(tab)`; its open state and position are `SettingsService.windowOpen`, `windowX` and `windowY`.
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
