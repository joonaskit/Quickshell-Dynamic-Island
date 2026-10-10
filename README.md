# Quickshell Island

A floating, morphing "island" top bar for KDE Plasma (Wayland), built with [Quickshell](https://quickshell.org) and QML.

A compact pill at the top of the screen shows the clock, media and notifications. It expands on hover or click into a full panel. It can also morph into a full-width top bar when a window is maximized.

## Features

- **Island pill:** clock, battery, now-playing media and notification alerts, with smooth expand and collapse animations.
- **Expanded view:** calendar, timer and stopwatch (running ones show in the pill), media controls, notifications, audio output selector, per-app volume mixer, and volume and brightness sliders. Notifications are grouped by app and support action buttons and inline replies, and clicking a notification preview in the pill opens it in place.
- **Status cluster:** Do Not Disturb, Wi-Fi, Bluetooth, microphone, clipboard history, power profile, hardware stats, USB devices, caffeine (inhibit idle) and battery. Each has a quick-settings popup.
- **Clipboard history:** a floating window (`./run.sh -v`) with search, text, link, image and file filters (copied images show a preview, copied files show their folder), pinning and details such as size, age and source app. History is kept in memory only. Copies from password managers are never recorded, credential-like text is hidden and expires, and an incognito mode pauses recording.
- **Desktop switch indicator:** switching virtual desktops briefly shows a row of dots with a sliding highlight in the island's OSD slot, even when the pill is hidden.
- **Left cluster:** active app, window controls, virtual desktop pill and system tray.
- **Window awareness:** hides on fullscreen and morphs or reserves space when a window is maximized, through a KWin script.
- **Settings UI:** toggle every icon and widget, UI and font scale, interface and display fonts, corner roundness, accent color, dock tint and opacity, an experimental light mode, caffeine that stays on across restarts, 24h clock and more. Settings are saved to `settings.json`.
- **Dock:** floating dock with an app launcher, enabled in `shell.qml`. The launcher has Recent and Frequent tabs, ranks search results by use, and has a Windows tab that works as a window switcher. Right-clicking the launcher button gives quick access to its settings. Popups on the dock morph between icons as you move from one to the next.

## Requirements

- KDE Plasma on Wayland (KWin)
- [Quickshell](https://quickshell.org)
- Python 3 with `dbus-python` and `PyGObject`
- CLI tools: `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl` / `pactl` (PipeWire or PulseAudio), `wl-clipboard`, `udisksctl`, `lsblk`, `systemd-inhibit`, `loginctl`, `busctl`, `qdbus-qt6`, `xdg-open`, `gtk-launch`, `notify-send` (timer alerts)
- Optional: `kioclient` (the dock's "Properties" entry) and `gio` (fallback for mounting USB drives)
- UPower, for battery, and power-profiles-daemon, for power profiles

## Usage

```bash
git clone <this-repo> ~/.config/quickshell/island   # or any directory
cd ~/.config/quickshell/island
./run.sh
```

| Command | Action |
| --- | --- |
| `./run.sh` | Start (restarts if already running) |
| `./run.sh -d` | Start in the background |
| `./run.sh -k` | Stop |
| `./run.sh -l` | Toggle the app launcher |
| `./run.sh -w` | Open the launcher on the open-windows tab (window switcher) |
| `./run.sh -v` | Toggle the clipboard history window |
| `./run.sh -t` | Toggle expanded view |
| `./run.sh -e` / `-c` | Expand / collapse |
| `./run.sh -i <target> <function>` | Call any IPC function, for example `-i system volumeUp` |

The toggle, expand and collapse commands use Quickshell IPC (`quickshell ipc call island ...`). `quickshell ipc call island toggleCaffeine` toggles caffeine. The `system` target has `toggleDnd`, `volumeUp`, `volumeDown`, `toggleMute`, `brightnessUp`, `brightnessDown`, `mediaPlayPause`, `mediaNext`, `mediaPrevious`, `startTimer <minutes>`, `toggleTimer`, `cancelTimer`, `toggleStopwatch` and `resetStopwatch`. The `clipboard` target has `toggle` and `toggleIncognito`. The `launcher` target has `toggle` and `windows`. You can bind these commands to a global shortcut by hand, or in the settings under Shortcuts, which saves them in KDE's shortcut settings (`scripts/shortcuts.py`). The `startTimer` shortcuts there come as 5, 10, 15 and 30 minute presets.

## Project layout

| Path | Purpose |
| --- | --- |
| `shell.qml` | Entry point, one `IslandWindow` per screen |
| `island/` | Island window, pill, expanded view, top bar clusters, views and settings UI |
| `widgets/` | Widgets in the expanded view and their registry, see `docs/WIDGETS.md` |
| `components/` | Shared pieces such as `SvgIcon` |
| `quicksettings/` | Popups for each status icon |
| `services/` | Backends (audio, network, Bluetooth, brightness, notifications, windows, ...) |
| `scripts/` | Helper scripts, including the KWin window tracker |
| `dock/` | Dock and app launcher |
| `clipboard/` | Clipboard history window |
| `docs/ANIMATION_CATALOGUE.md` | Reference for all animations |
| `docs/WIDGETS.md` | How to add a widget to the expanded view |
| `docs/THEME.md` | Theme file exported for companion apps |
| `examples/` | Reference code for companion apps, such as a theme reader |
| `tests/` | Unit tests, run with `./test.sh` |

## Configuration

Use the in-app settings view, or edit `settings.json` directly. Changes are picked up on restart. Pinned dock apps are stored in `dock_pinned.json`. Both files are gitignored, as is `launcher_usage.json`, where the launcher keeps its usage counts. To start from the defaults, copy `settings.json.example` and `dock_pinned.json.example` to those names.

The shell also writes its colors, fonts and scale to `~/.config/quickshell-island/theme.json`, so companion apps can match its look. See `docs/THEME.md`.

## Development

Run `./lint.sh` before committing. It runs `qmllint` on the QML files (settings in `.qmllint.ini`) and `ruff` on the Python files (settings in `ruff.toml`). It needs the Qt 6 declarative tools for `qmllint`, and either `ruff` or `uv` for the Python check.

`./test.sh` runs the unit tests in `tests/`: the QML ones headless with `qmltestrunner`, and the Python ones with `unittest`. They cover pure logic that has been moved into plain JS files, such as the window-to-app matching in `dock/windowMatching.js`, the reading of older `settings.json` formats in `services/settingsMigration.js`, and the clipboard history logic in `services/clipboardHistory.js` and `scripts/clipboard_tracker.py`. The UI is checked by hand in the running shell.

## License

Licensed under the [GNU General Public License v3.0 or later](LICENSE) (GPL-3.0-or-later).
