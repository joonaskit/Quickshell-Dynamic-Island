# Quickshell Island

A floating, morphing "island" top bar for KDE Plasma (Wayland), built with [Quickshell](https://quickshell.org) and QML.

A compact pill at the top of the screen shows the clock, media and notifications. It expands on hover or click into a full panel. It can also morph into a full-width top bar when a window is maximized.

## Features

- **Island pill:** clock, battery, now-playing media and notification alerts, with smooth expand and collapse animations.
- **Expanded view:** calendar, media controls, notifications, audio output selector, and volume and brightness sliders.
- **Status cluster:** Wi-Fi, Bluetooth, microphone, clipboard history, power profile, hardware stats, USB devices, caffeine (inhibit idle) and battery. Each has a quick-settings popup.
- **Left cluster:** active app, window controls, virtual desktop pill and system tray.
- **Window awareness:** hides on fullscreen and morphs or reserves space when a window is maximized, through a KWin script.
- **Settings UI:** toggle every icon and widget, UI and font scale, 24h clock and more. Settings are saved to `settings.json`.
- **Dock:** floating dock implementation (disabled by default, see `shell.qml`).

## Requirements

- KDE Plasma on Wayland (KWin)
- [Quickshell](https://quickshell.org)
- Python 3 with `dbus-python` and `PyGObject`
- CLI tools: `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl` / `pactl` (PipeWire or PulseAudio), `wl-clipboard`, `udisksctl`, `lsblk`, `systemd-inhibit`, `loginctl`, `qdbus`
- UPower, for battery

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
| `./run.sh -t` | Toggle expanded view |
| `./run.sh -e` / `-c` | Expand / collapse |

The toggle, expand and collapse commands use Quickshell IPC (`quickshell ipc call island ...`). You can bind them to a global shortcut.

## Project layout

| Path | Purpose |
| --- | --- |
| `shell.qml` | Entry point, one `IslandWindow` per screen |
| `IslandWindow.qml`, `IslandPill.qml`, `ExpandedView.qml` | Main island and its expanded panel |
| `TopLeftAppCluster.qml`, `TopRightStatusCluster.qml`, `VirtualDesktopsPill.qml`, `AppIndicatorPill.qml` | Top bar clusters |
| `quicksettings/` | Popups for each status icon |
| `services/` | Backends (audio, network, Bluetooth, brightness, notifications, windows, ...) |
| `scripts/` | Helper scripts, including the KWin window tracker |
| `services/Theme.qml`, `services/SettingsService.qml`, `SvgIcon.qml`, `SettingsView.qml` | Theming, icons and settings |
| `docs/ANIMATION_CATALOGUE.md` | Reference for all animations |

## Configuration

Use the in-app settings view, or edit `settings.json` directly. Changes are picked up on restart. Pinned dock apps are stored in `dock_pinned.json`.
