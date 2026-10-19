# Quickshell Island

A floating, morphing "island" top bar for KDE Plasma (Wayland), built with [Quickshell](https://quickshell.org) and QML.

A compact pill at the top of the screen shows the clock, media and notifications. It expands on hover or click into a full panel. It can also morph into a full-width top bar when a window is maximized.

## Features

- **Island pill:** clock, battery, now-playing media and notification alerts, with smooth expand and collapse animations.
- **Expanded view:** calendar, timer and stopwatch (running ones show in the pill), media controls, notifications, audio output selector, per-app volume mixer, and volume and brightness sliders. Notifications are grouped by app and support action buttons and inline replies, and clicking a notification preview in the pill opens it in place.
- **Status cluster:** Do Not Disturb, Wi-Fi, Bluetooth, microphone, clipboard history, power profile, hardware stats, USB devices, caffeine (inhibit idle) and battery. Each has a quick-settings popup.
- **Philips Hue (optional):** off by default. Turn it on in the settings under Widgets to get a lamp icon whose popup pairs with a Hue Bridge on your network and controls a lamp's power, brightness and white temperature. The bridge address and app key are saved in `settings.json`. Bluetooth-only bulbs are not supported.
- **Night Light (optional):** off by default. Turn it on in the settings under Widgets to get a moon icon whose popup switches KDE Night Light on and off, sets the night temperature and chooses between sunset to sunrise, custom hours (a start and an end time) and always on. Changes are saved in `kwinrc`, and the Night Light plugin is reloaded to apply them. The widget icons sit at the start of the status cluster, apart from the system icons by a thin divider.
- **KDE Connect (optional):** off by default. Turn it on in the settings under Widgets to get a phone icon whose popup shows a paired device's connection and battery (when the device reports one) and can ping it, send the clipboard, a file, text or a link, and make it ring. Only the actions the device supports are enabled. Pair the phone from the KDE Connect app first.
- **GameMode (optional):** off by default. Turn it on in the settings under Widgets to get a gamepad icon that lights up while Feral GameMode is applied to a game (started with `gamemoderun`, or by Steam, Lutris or Heroic). Its popup lists those games and has a switch that forces GameMode on without a game, for emulators and other apps that cannot start it themselves. The forced state ends when the shell exits. Needs the `gamemode` package.
- **Clipboard history:** a floating window (`./run.sh -v`) with search, text, link, image and file filters (copied images show a preview, copied files show their folder), pinning and details such as size, age and source app. History is kept in memory only. Copies from password managers are never recorded, credential-like text is hidden and expires, and an incognito mode pauses recording.
- **Desktop switch indicator:** switching virtual desktops briefly shows a row of dots with a sliding highlight in the island's OSD slot, even when the pill is hidden.
- **Left cluster:** active app, window controls, virtual desktop pill and system tray.
- **Window awareness:** hides on fullscreen and morphs or reserves space when a window is maximized, through a KWin script.
- **Settings UI:** toggle every icon and widget, UI and font scale, interface and display fonts, corner roundness, accent color, dock tint and opacity, an experimental light mode, caffeine that stays on across restarts, 24h clock and more. Settings are saved to `settings.json`.
- **Dock:** floating dock with an app launcher, enabled in `shell.qml`. The launcher has Recent and Frequent tabs, ranks search results by use, and has a Windows tab that works as a window switcher. The search box also answers sums (`2*(3+4)`), unit conversions (`5 km in mi`) and web search shortcuts (`g cats`, configurable in the Launcher settings); Enter copies the result or opens the search. With File Search turned on in the same settings, ordinary typing also finds files and folders by name through [Filehouse](https://github.com/joonaskit/filehouse) (`filehouse --search`): the launcher grows taller and lists the apps first, then a line, then the files. Down moves from the apps into the files; Enter opens one and Alt+Enter shows it in its folder. `f report 2024` lists only files. Right-clicking the launcher button gives quick access to its settings. Popups on the dock morph between icons as you move from one to the next. The Downloads stack and the Trash at the end of the dock can each be turned off in the Dock settings.

## Requirements

- KDE Plasma on Wayland (KWin)
- [Quickshell](https://quickshell.org)
- Python 3 with `dbus-python` and `PyGObject`
- CLI tools: `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl` / `pactl` (PipeWire or PulseAudio), `wl-clipboard`, `udisksctl`, `lsblk`, `systemd-inhibit`, `loginctl`, `busctl`, `qdbus-qt6`, `xdg-open`, `gtk-launch`, `notify-send` (timer alerts)
- Optional: `kioclient` (the dock's "Properties" entry) and `gio` (fallback for mounting USB drives)
- UPower, for battery, and power-profiles-daemon, for power profiles

Run `./run.sh --check` to see which of these are missing on your system, which features each one affects and the command that installs them. `./run.sh --check --json` prints the same result as JSON. The list it checks is `deps.json`.

The shell runs the same check at startup. A status icon whose tool is missing (for example Wi-Fi without `nmcli`) is dimmed and does nothing, and hovering it names the missing tool and its package. The brightness, volume and audio output controls say which tool they need (`brightnessctl`, `wpctl`, `pactl`). In the settings under Top Bar, the Status Bar Icon Order list names the missing tool and its package, and "Hide Icons With Missing Tools" removes those icons instead of dimming them. The power menu and battery icon are never affected. Install the tool and restart the shell, or press "Check again" in the welcome guide, to bring the feature back.

## Installation

```bash
git clone https://github.com/joonaskit/Quickshell-Dynamic-Island ~/.config/quickshell/island
cd ~/.config/quickshell/island
./install.sh
```

The installer checks your system with `./run.sh --check` and shows the command that installs what is missing (Arch, Fedora, openSUSE and Debian or Ubuntu). It runs that command only if you answer yes, because it uses `sudo`. It then creates `settings.json` and `dock_pinned.json` from the `.example` files if you have none, and sets the shell to start at login with an entry in `~/.config/autostart/`. It never overwrites your configuration, and running it again updates the shell with `git pull` and changes nothing else. The welcome guide opens the first time the shell starts.

| Option | Effect |
| --- | --- |
| `--prefix <dir>` | Install in `<dir>` instead of `~/.config/quickshell/island`. Run from another checkout, it clones the shell there |
| `--no-deps` | Do not offer to install missing packages |
| `--no-autostart` | Do not start the shell at login |
| `--import <file>` | Load a configuration exported with `./run.sh --export` |
| `--yes` | Ask nothing and take the defaults. Packages are then never installed, only the command is shown |
| `--dry-run` | Show what would happen and change nothing |
| `--uninstall` | Remove the autostart entry and the shell, and ask whether to delete your configuration too |

You can also skip the installer: install the requirements above, clone the repository anywhere and run `./run.sh`.

## Usage

```bash
./run.sh
```

| Command | Action |
| --- | --- |
| `./run.sh` | Start (restarts if already running) |
| `./run.sh -d` | Start in the background |
| `./run.sh -k` | Stop |
| `./run.sh --check` | Check for missing tools and services |
| `./run.sh --run <command>` | Run a command and show its progress in the island, see `docs/ACTIVITIES_API.md`. The installer also adds this as `island-run` (skip it with `--no-link`) |
| `./run.sh --export <file>` | Save the configuration to one file |
| `./run.sh --import <file>` | Load a configuration file, see below |
| `./run.sh -l` | Toggle the app launcher |
| `./run.sh -w` | Open the launcher on the open-windows tab (window switcher) |
| `./run.sh -v` | Toggle the clipboard history window |
| `./run.sh -t` | Toggle expanded view |
| `./run.sh -e` / `-c` | Expand / collapse |
| `./run.sh -i <target> <function>` | Call any IPC function, for example `-i system volumeUp` |

The toggle, expand and collapse commands use Quickshell IPC (`quickshell ipc call island ...`). `quickshell ipc call island toggleCaffeine` toggles caffeine. The `system` target has `toggleDnd`, `volumeUp`, `volumeDown`, `toggleMute`, `brightnessUp`, `brightnessDown`, `mediaPlayPause`, `mediaNext`, `mediaPrevious`, `startTimer <minutes>`, `toggleTimer`, `cancelTimer`, `toggleStopwatch` and `resetStopwatch`. The `clipboard` target has `toggle` and `toggleIncognito`. The `launcher` target has `toggle` and `windows`. The `onboarding` target has `open`, which shows the welcome guide, and the `config` target has `reload`, which re-reads the config files from disk. You can bind these commands to a global shortcut by hand, or in the settings under Shortcuts, which saves them in KDE's shortcut settings (`scripts/shortcuts.py`). The `startTimer` shortcuts there come as 5, 10, 15 and 30 minute presets.

## Welcome guide

On a new install (no `settings.json`, or one whose `onboardingVersion` is `0`, as in `settings.json.example`) the shell opens a welcome guide in the middle of the first screen. Its six steps are: a short tour, a system check (the same as `./run.sh --check`, with the install command to copy), importing a configuration, a few starting choices (clock, sizes, dock position, status icons), tips for the launcher and keyboard shortcuts, and a summary. Every step can be skipped, and closing the guide at any point is enough for it not to come back. The choices are ordinary settings, saved as you make them.

Open it again from the settings under About, or with `./run.sh -i onboarding open`.

## Backing up and moving the configuration

`./run.sh --export <file>` writes the settings and the pinned dock apps to one JSON file, and `./run.sh --import <file>` loads such a file. The same two actions are in the settings under About, with a file dialog (`kdialog` or `zenity`; without either you type the path).

- The launcher's usage history is personal, so it is only exported with `--usage`.
- The Hue bridge key and the ids of paired devices are left out unless you add `--with-secrets`, so an export is safe to share. An import without them keeps the values this machine already has.
- `--sections settings,dock,usage` limits an export or an import to those parts.
- An import is checked before anything changes. A file that is malformed or made by a newer version is refused and nothing is touched. Keys this version does not know are ignored, and settings missing from the file go back to their defaults.
- The files an import replaces are first copied to `~/.local/state/quickshell-island/backups/<time>/`. Copy them back into the shell's folder to undo it.
- A running shell takes the imported configuration at once.

The file format is described in `docs/CONFIG_EXPORT.md`.

## Project layout

| Path | Purpose |
| --- | --- |
| `shell.qml` | Entry point, one `IslandWindow` per screen |
| `island/` | Island window, pill, expanded view, top bar clusters, views and settings UI |
| `onboarding/` | Welcome guide shown on a new install |
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
| `docs/ACTIVITIES_API.md` | D-Bus API for apps to show progress and status in the island |
| `examples/` | Reference code for companion apps, such as a theme reader and an activities client |
| `tests/` | Unit tests, run with `./test.sh` |

## Configuration

Use the in-app settings view, or edit `settings.json` directly. Changes are picked up on restart. Pinned dock apps are stored in `dock_pinned.json`. Both files are gitignored, as is `launcher_usage.json`, where the launcher keeps its usage counts. To start from the defaults, copy `settings.json.example` and `dock_pinned.json.example` to those names.

The shell also writes its colors, fonts and scale to `~/.config/quickshell-island/theme.json`, so companion apps can match its look. See `docs/THEME.md`.

Other apps can show progress in the island, such as a file copy, through a small D-Bus API: `docs/ACTIVITIES_API.md`. It needs `python-dbus` and `python-gobject`, like the other helper scripts.

## Development

Run `./lint.sh` before committing. It runs `qmllint` on the QML files (settings in `.qmllint.ini`) and `ruff` on the Python files (settings in `ruff.toml`). It needs the Qt 6 declarative tools for `qmllint`, and either `ruff` or `uv` for the Python check.

`./test.sh` runs the unit tests in `tests/`: the QML ones headless with `qmltestrunner`, and the Python ones with `unittest`. They cover pure logic that has been moved into plain JS files, such as the window-to-app matching in `dock/windowMatching.js`, the reading of older `settings.json` formats in `services/settingsMigration.js`, and the clipboard history logic in `services/clipboardHistory.js` and `scripts/clipboard_tracker.py`. The UI is checked by hand in the running shell.

## License

Licensed under the [GNU General Public License v3.0 or later](LICENSE) (GPL-3.0-or-later).
