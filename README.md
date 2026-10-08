# Quickshell Island

A floating, morphing "island" top bar for KDE Plasma (Wayland), built with [Quickshell](https://quickshell.org) and QML.

A compact pill at the top of the screen shows the clock, media and notifications. It expands on hover or click into a full panel. It can also morph into a full-width top bar when a window is maximized.

## Features

- **Island pill:** clock, battery, now-playing media and notification alerts, with smooth expand and collapse animations.
- **Expanded view:** calendar, timer and stopwatch (running ones show in the pill), media controls, notifications, audio output selector, per-app volume mixer, and volume and brightness sliders. Notifications are grouped by app and support action buttons and inline replies.
- **Status cluster:** Do Not Disturb, Wi-Fi, Bluetooth, microphone, clipboard history, power profile, hardware stats, USB devices, caffeine (inhibit idle) and battery. Each has a quick-settings popup.
- **Left cluster:** active app, window controls, virtual desktop pill and system tray.
- **Window awareness:** hides on fullscreen and morphs or reserves space when a window is maximized, through a KWin script.
- **Settings UI:** toggle every icon and widget, UI and font scale, 24h clock and more. Settings are saved to `settings.json`.
- **Dock:** floating dock with an app launcher, enabled in `shell.qml`. The launcher has Recent and Frequent tabs, ranks search results by use, and has a Windows tab that works as a window switcher.

## Requirements

- KDE Plasma on Wayland (KWin)
- [Quickshell](https://quickshell.org)
- Python 3 with `dbus-python` and `PyGObject`
- CLI tools: `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl` / `pactl` (PipeWire or PulseAudio), `wl-clipboard`, `udisksctl`, `lsblk`, `systemd-inhibit`, `loginctl`, `busctl`, `qdbus-qt6`, `xdg-open`, `gtk-launch`
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
| `./run.sh -t` | Toggle expanded view |
| `./run.sh -e` / `-c` | Expand / collapse |
| `./run.sh -i <target> <function>` | Call any IPC function, for example `-i system volumeUp` |

The toggle, expand and collapse commands use Quickshell IPC (`quickshell ipc call island ...`). `quickshell ipc call island toggleCaffeine` toggles caffeine. The `system` target has `toggleDnd`, `volumeUp`, `volumeDown`, `toggleMute`, `brightnessUp`, `brightnessDown`, `mediaPlayPause`, `mediaNext`, `mediaPrevious`, `startTimer <minutes>`, `toggleTimer`, `cancelTimer`, `toggleStopwatch` and `resetStopwatch`. You can bind these commands to a global shortcut.

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
| `docs/ANIMATION_CATALOGUE.md` | Reference for all animations |
| `docs/WIDGETS.md` | How to add a widget to the expanded view |

## Configuration

Use the in-app settings view, or edit `settings.json` directly. Changes are picked up on restart. Pinned dock apps are stored in `dock_pinned.json`. Both files are gitignored. To start from the defaults, copy `settings.json.example` and `dock_pinned.json.example` to those names.

## License

Licensed under the [GNU General Public License v3.0 or later](LICENSE) (GPL-3.0-or-later).
