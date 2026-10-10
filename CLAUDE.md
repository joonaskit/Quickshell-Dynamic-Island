# Quickshell Island

QML desktop shell for KDE Plasma (Wayland), built with Quickshell: a morphing top "island" bar plus a dock and app launcher. See README.md for features and requirements.

## Layout

- `shell.qml` is the entry point. It creates `IslandWindow` and `DockWindow` per screen and registers the `launcher` IPC handler.
- `services/*Service.qml` files are singletons that own state and talk to the system. Views bind to them and hold no system logic.
- `qmldir` registers every singleton and component. Add new QML files there. Files in subfolders (e.g. `dock/`) must `import ".."` to see the root types.
- `services/Theme.qml` holds colors, sizes and scale. Use it instead of hardcoding values.
- `scripts/` holds the Python helpers (`kwin_window_tracker.py`, `hardware_stats.py`, `devices.py`, `audio_*.py`, `downloads_tracker.py`, `clipboard_tracker.py`, `shortcuts.py`) that feed data to the services. `scripts/kwin_script.js` runs inside KWin, loaded by the tracker from its own directory.
- `dock/` holds the dock (`Dock*.qml`, including `DockService`).
- `clipboard/` holds the clipboard history window. `ClipboardService` fills it from `scripts/clipboard_tracker.py`, and the history logic is in `services/clipboardHistory.js`. History stays in memory only, so never write it to disk. The one exception is copied images: the tracker saves them under `$XDG_RUNTIME_DIR` (tmpfs), deletes them when entries go, and wipes the folder when it starts and stops.
- `quicksettings/` holds the quick-settings popups, selectors and sliders.
- `services/` holds the `*Service.qml` singletons and `Theme.qml`.
- `island/` holds the island window, pills, clusters, views and settings UI.
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
