# Apple-like Dynamic Island for Quickshell (Fedora KDE)

A fluid, organic Apple Dynamic Island pill widget built with **Quickshell** (Qt 6 QML) for Fedora KDE Plasma (Wayland).

Positioned at the top center of the screen, it shows the current time by default and dynamically morphs to display active media playback, audio controls, display brightness, battery status, and an interactive expanded widget card.

---

## ✨ Features

- **Default Time Pill**:
  - Displays the current time in clean Apple typography with tabular digits.
  - Accompanied by a glowing clock icon and weekday badge.
  - OLED True Black capsule (`#000000`) with a subtle 1px translucent border and ambient drop shadow.

- **Dynamic Island Morphing**:
  - **Now Playing**: When media is playing (Spotify, Firefox, Chrome, VLC, Elisa, etc.), the pill smoothly expands to reveal album artwork, track title, and an animated dancing equalizer sound wave.
  - **Liquid Jelly Physics**: Smooth spring-like animations (`Easing.OutBack` with subtle overshoot) for widths, heights, and corner radii.

- **Interactive Expanded Island** (Click or Tap):
  - **Header**: Large clock with seconds, full date, battery badge (with charging bolt or nuclear icon if no battery), and a collapse button.
  - **Mini Calendar Widget**: Clean Apple-style calendar with ISO week numbers (`Wk`), month navigation (`<` / `>`), today jump button, and highlighted active date badge.
  - **Media Player**: Full track info, album art, interactive seekable progress bar, and Previous / Play-Pause / Next controls (MPRIS).
  - **Notification History**: Interactive card list showing app badges, timestamps, summary, body, per-notification dismiss (`✕`), and a one-click "Clear" button.
  - **Audio Output Device Switcher**: Dropdown allowing instant selection between connected headphones, speakers, and HDMI audio sinks directly in the pill.
  - **Volume Slider**: Interactive system volume slider and mute toggle using WirePlumber/PipeWire (`wpctl`), with real-time sync when pressing keyboard volume keys.
  - **Brightness Slider**: Interactive display brightness slider using `brightnessctl` (gracefully hidden on desktop monitors without backlight).
  - **Adaptive Screen Bounds & Scrolling**: Automatically adapts to screen resolution up to 1150px window buffer height with mouse-wheel scrolling (`Flickable`) when content is extensive, ensuring the bottom rounded border and grabber handle are always fully preserved.
  - **Auto-Collapse**: Smoothly collapses back to the compact pill when clicking the collapse handle/close button or after mouse inactivity.

- **iPhone-Style Dual Island & Notifications**:
  - **Notification Banner Animation**: When a notification arrives, the main pill smoothly morphs open (width expands to 310px) displaying the app name, preview, and an orange breathing pulse for 4.5 seconds.
  - **Detached Dual-Island Bubble**: A secondary detached 38×38 OLED black circle sits beside the pill (Apple iPhone dual-island style) showing an orange bell icon and an unread counter badge. Clicking the bubble immediately opens the expanded notification view.
  - **Zero-Conflict DBus Monitoring**: Seamlessly monitors desktop notifications (`org.freedesktop.Notifications`) without interfering with KDE Plasma's notification manager.

- **Status & Notification Cluster Morphing**:
  - **Fluid Capsule Morphing**: Instead of opening static disconnected popovers, clicking any button in the top-right cluster smoothly morphs the entire capsule into an expanded OLED black card with the exact same spring physics (`Easing.OutBack` with overshoot 1.15) as the Dynamic Island pill.
  - **Dynamic Tab Switching**: Easily click another icon while morphed to fluidly transition between menus, with height adapting dynamically to the content.
  - **Bouncy Spring Button Animations**: All buttons feature tactile spring physics—scaling up to `1.12` on hover with overshoot and pressing down to `0.90` on click.
  - **Microphone Mute & Input Volume**: One-click master mic mute toggle, input volume slider, and input device switcher (`pactl` / PipeWire).
  - **Performance Profiles (Power Mode)**: One-tap switching between Power Saver, Balanced, and High Performance profiles via `tuned-ppd` / `net.hadess.PowerProfiles`.
  - **Hardware Resource Monitor (Mini Stats)**: Real-time gauges for CPU usage %, RAM usage (GB used / total), and live CPU temperature (°C).
  - **Notification History Menu**: Dedicated Notification Bell button displaying an unread badge dot; clicking it morphs into the notification history card list with per-item dismissal and clear-all.
  - **Clipboard Manager**: One-click clipboard history, preview of current clipboard contents, copy history items, and one-click clear clipboard function (`wl-clipboard`).
  - **Nuclear Desktop Icon**: Systems without a battery (like desktop workstations) display a cool nuclear reactor symbol instead of an empty battery icon.

- **Persistent Application Indicator Pill**:
  - **Dynamic Left-Side Pill**: A dedicated OLED black capsule positioned directly to the left of the status & notifications cluster (`anchors.right: statusCluster.left; anchors.rightMargin: 8`).
  - **Conditional Visibility**: Only shown when one or more background/tray applications (e.g. Discord, Steam, Spotify, Slack, Telegram, etc.) are open and active. Automatically hides with smooth spring-scale exit when no target apps are open.
  - **Apple OLED Styling**: Styled in pure black (`Theme.islandBackground`) with a subtle 1px border (`Theme.islandBorder`), matching 19px corner radius, and ambient drop shadow.
  - **Direct Activation & Focus**: Left-clicking an icon immediately focuses/raises the application window via native StatusNotifierItem `activate()` and KWin window management.
  - **Secondary Mouse Button Context Menu (Liquid Morphing)**: Right-clicking an app icon liquidly morphs the entire pill capsule itself—expanding its width and height downwards with the exact same spring jelly physics (`Easing.OutBack` with overshoot) as the notification buttons in `TopRightStatusCluster`.
  - **Native DBusMenu Actions**: The morphed capsule displays the app title, close button, and dynamically parsed menu items via `QsMenuOpener`, providing full access to actions like **"Quit Discord"**, **"Exit Steam"**, **"Check for Updates..."**, **"Mute"**, **"Deafen"**, and checkable status options, with exit actions highlighted in subtle red. Clicking outside or selecting an action fluidly morphs the card back into the compact capsule.
  - **Floating Tooltips**: Hovering over an app icon displays a sleek, dark-glass floating tooltip badge with the application title.
  - **Live Tray Badges**: Binds directly to the application's StatusNotifierItem pixmap, instantly displaying unread mention badges (e.g. Discord red ping dots).

- **Maximization Morphing (Fluid Dynamic Top Bar)**:
  - **Fluid Growth Out of Center Pill**: When a window is **maximized**, the black bar physically **grows horizontally outward from the Dynamic Island capsule** in both directions simultaneously towards the screen edges (`width: compactWidth -> parent.width`).
  - **Synchronized Geometry Glide**: The bar seamlessly glides upward (`y: 10 -> 0`), height compacts (`38px -> 35px`), and corner radii smoothly flatten from `19px` to `0px` in mathematical lockstep with the center pill and right status cluster using smooth `Easing.OutCubic` animation.
  - **Fluid Retraction on Unmaximize**: In reverse, when unmaximizing a window, the full-width top bar pulls back in from both screen edges, rounding its ends back to `19px` capsules and settling fluidly back down to `y: 10` as the floating Dynamic Island.
  - **Active App Badge & Hairline Border**: As the black wings reach the left edge, the active application icon and name (e.g. "Firefox", "Steam", "Code") smoothly fade in at the top-left, and a razor-thin `1px` translucent bottom hairline border (`Qt.rgba(1, 1, 1, 0.12)`) illuminates along the bottom edge. Clicking the app name raises and focuses the window.
  - **Center & Right Continuity**: Dynamic Island clock and media visualizer remain perfectly centered without borders or rounded corner artifacts in top-bar mode, while the persistent app indicator pill and status cluster sit seamlessly inside the continuous bar.
  - **Window Placement**: Automatically reserves an exclusive zone so the maximized window sits neatly **underneath** the bar without any tabs or titlebar buttons being obstructed!

- **Wayland & KDE Plasma Native**:
  - **Click-Through Masking**: Uses Quickshell's `Region` input mask so **only** the visible pill, detached bubble, expanded card, status cluster, and popovers capture mouse clicks. The transparent window area around it is 100% click-through to apps underneath.
  - **Fullscreen Auto-Hide**: Automatically fades away and clears all input when a game or full-screen video starts.
  - **IPC Support**: Can be expanded or collapsed via terminal or KDE custom keyboard shortcuts.

---

## 🚀 Quick Start

### 1. Run in Foreground (Testing)
```bash
cd /home/jkikke/code/git/quickshell
./run.sh
```
Or directly using the `quickshell` CLI:
```bash
quickshell -p /home/jkikke/code/git/quickshell
```

### 2. Run as a Background Daemon
```bash
./run.sh -d
```

### 3. Stop / Kill
```bash
./run.sh -k
```

### 4. Toggle via IPC (Command Line or Shortcut)
```bash
./run.sh -t
# or directly:
quickshell ipc -p /home/jkikke/code/git/quickshell call island toggle
```

---

## ⌨️ KDE Plasma Global Shortcut (Optional)

To toggle or expand the Dynamic Island with a keyboard shortcut (e.g. `Meta + I` or `Meta + Space`):

1. Open **KDE System Settings** → **Shortcuts** → **Custom Shortcuts** (or **Command Shortcuts**).
2. Add a new Command shortcut:
   - **Name**: `Toggle Dynamic Island`
   - **Trigger**: `Meta+I` (or your preferred shortcut)
   - **Action**:
     ```bash
     quickshell ipc -p /home/jkikke/code/git/quickshell call island toggle
     ```

---

## ⚙️ Configuration & Customization

All design tokens and behavior settings can be modified in [`Theme.qml`](file:///home/jkikke/code/git/quickshell/Theme.qml):

| Property | Default | Description |
| :--- | :--- | :--- |
| `use24Hour` | `true` | `true` for 24-hour time (`19:04`), `false` for 12-hour AM/PM |
| `showSeconds` | `true` | Shows seconds in the expanded clock view |
| `showBattery` | `true` | Shows battery status badge when battery is detected |
| `showMediaWhenPlaying` | `true` | Morphs to Now Playing pill when music/video is playing |
| `hideOnFullscreen` | `true` | Automatically hides the pill and releases all input when a game or video is fullscreen |
| `morphToTopBarWhenMaximized` | `true` | Morphs into full-width top bar when active window is maximized |
| `reserveSpaceWhenMaximized` | `true` | Reserves top bar space so the maximized window sits neatly underneath it |
| `topBarHeight` | `34` | Height (px) of the top bar in maximized mode |
| `topMargin` | `10` | Floating distance (px) from the top edge of the screen |
| `compactWidthClock` | `154` | Width of the pill in compact clock mode |
| `compactWidthMedia` | `228` | Width of the pill when media is playing |
| `expandedWidth` | `410` | Width of the expanded card |
| `autoCollapseTimeout` | `6000` | Inactivity delay (ms) before auto-collapsing |
| `allScreens` | `false` | `false` for primary monitor only, `true` for all connected monitors |

---

## 📁 File Structure

- [`shell.qml`](file:///home/jkikke/code/git/quickshell/shell.qml) - Root entrypoint, multi-monitor configuration via `Variants`.
- [`IslandWindow.qml`](file:///home/jkikke/code/git/quickshell/IslandWindow.qml) - Wayland `PanelWindow` overlay with click-through `Region` mask, dynamic `exclusiveZone`, and IPC handler.
- [`TopBarWings.qml`](file:///home/jkikke/code/git/quickshell/TopBarWings.qml) - Edge-to-edge top bar wings displaying active app title and date/battery status when maximized.
- [`IslandPill.qml`](file:///home/jkikke/code/git/quickshell/IslandPill.qml) - Core Dynamic Island container managing state transitions, notification alert expansion, top-bar mode, and spring physics.
- [`IslandDetachedBubble.qml`](file:///home/jkikke/code/git/quickshell/IslandDetachedBubble.qml) - Secondary detached OLED circle beside the pill (iPhone dual-island style) with unread notification counter.
- [`CompactClockView.qml`](file:///home/jkikke/code/git/quickshell/CompactClockView.qml) - Default Apple pill displaying current time and date badge.
- [`CompactMediaView.qml`](file:///home/jkikke/code/git/quickshell/CompactMediaView.qml) - Now-Playing state with album art, time, and animated equalizer.
- [`CompactNotificationAlertView.qml`](file:///home/jkikke/code/git/quickshell/CompactNotificationAlertView.qml) - Fluid notification arrival banner inside the pill with pulsing indicator.
- [`ExpandedView.qml`](file:///home/jkikke/code/git/quickshell/ExpandedView.qml) - Expanded interactive card with clock, mini calendar, media controls, notification list, audio output selector, volume slider, and brightness slider.
- [`MiniCalendarWidget.qml`](file:///home/jkikke/code/git/quickshell/MiniCalendarWidget.qml) - Apple-styled mini monthly calendar with ISO week numbers (`Wk`), month navigation, and today highlighting.
- [`NotificationListView.qml`](file:///home/jkikke/code/git/quickshell/NotificationListView.qml) - Notification cards list in expanded view with per-item dismissal and clear-all.
- [`NotificationService.qml`](file:///home/jkikke/code/git/quickshell/NotificationService.qml) - Singleton service managing notification queue, unread counters, and alert timing.
- [`notification_tracker.py`](file:///home/jkikke/code/git/quickshell/notification_tracker.py) - DBus monitor daemon streaming incoming notifications via `BecomeMonitor`.
- [`MediaWidget.qml`](file:///home/jkikke/code/git/quickshell/MediaWidget.qml) - MPRIS media player controls and seekable progress bar.
- [`AudioService.qml`](file:///home/jkikke/code/git/quickshell/AudioService.qml) - Audio service managing volume, mute sync via `wpctl`, and sink switching.
- [`AudioOutputSelector.qml`](file:///home/jkikke/code/git/quickshell/AudioOutputSelector.qml) - Interactive audio output sink switcher dropdown inside the extended pill.
- [`audio_sinks.py`](file:///home/jkikke/code/git/quickshell/audio_sinks.py) - PipeWire/PulseAudio sink query and switching helper script.
- [`MicrophoneService.qml`](file:///home/jkikke/code/git/quickshell/MicrophoneService.qml) - Singleton service managing microphone mute, input volume, and device selection.
- [`MicrophoneQuickSettings.qml`](file:///home/jkikke/code/git/quickshell/MicrophoneQuickSettings.qml) - Morphed panel with mic mute toggle, input volume slider, and input device switcher.
- [`audio_sources.py`](file:///home/jkikke/code/git/quickshell/audio_sources.py) - PipeWire/PulseAudio source query and switching helper script.
- [`PowerProfileService.qml`](file:///home/jkikke/code/git/quickshell/PowerProfileService.qml) - Singleton service interfacing with `net.hadess.PowerProfiles` / `tuned-ppd`.
- [`PowerProfileQuickSettings.qml`](file:///home/jkikke/code/git/quickshell/PowerProfileQuickSettings.qml) - Morphed panel with Power Saver, Balanced, and High Performance profiles.
- [`HardwareStatsService.qml`](file:///home/jkikke/code/git/quickshell/HardwareStatsService.qml) - Singleton service streaming real-time CPU %, RAM %, and CPU temperature.
- [`HardwareStatsQuickSettings.qml`](file:///home/jkikke/code/git/quickshell/HardwareStatsQuickSettings.qml) - Morphed panel with live meters for CPU, memory, and thermals.
- [`hardware_stats.py`](file:///home/jkikke/code/git/quickshell/hardware_stats.py) - Background daemon measuring real-time CPU, RAM, and CPU temperature.
- [`DeviceService.qml`](file:///home/jkikke/code/git/quickshell/DeviceService.qml) - Singleton service managing detachable drives (USB sticks, external disks), mounting, unmounting, and safe power-off removal.
- [`DeviceQuickSettings.qml`](file:///home/jkikke/code/git/quickshell/DeviceQuickSettings.qml) - Morphed panel displaying connected detachable devices, partition storage meters, file manager browse, mount/unmount toggles, and safe eject.
- [`devices.py`](file:///home/jkikke/code/git/quickshell/devices.py) - Helper script and real-time monitor daemon for detachable block devices, UDisks2 mounting, unmounting, and drive power-off.
- [`VolumeSlider.qml`](file:///home/jkikke/code/git/quickshell/VolumeSlider.qml) - Interactive volume slider with mute toggle button.
- [`BrightnessService.qml`](file:///home/jkikke/code/git/quickshell/BrightnessService.qml) - Display backlight service managing brightness via `brightnessctl`.
- [`BrightnessSlider.qml`](file:///home/jkikke/code/git/quickshell/BrightnessSlider.qml) - Interactive screen brightness slider with sun icon.
- [`AudioVisualizer.qml`](file:///home/jkikke/code/git/quickshell/AudioVisualizer.qml) - 4-bar animated soundwave equalizer.
- [`AppIndicatorPill.qml`](file:///home/jkikke/code/git/quickshell/AppIndicatorPill.qml) - Persistent application indicator capsule positioned to the left of the notification cluster, displaying live tray icons for active background apps (Discord, Steam, Spotify, etc.).
- [`TopRightStatusCluster.qml`](file:///home/jkikke/code/git/quickshell/TopRightStatusCluster.qml) - Morphed status capsule with Caffeine, Wi-Fi, Bluetooth, Microphone, Clipboard, Performance, Hardware Stats, Detachable Devices, Notifications, and Power.
- [`ClipboardService.qml`](file:///home/jkikke/code/git/quickshell/ClipboardService.qml) - Wayland clipboard service with history tracking, copy, and clear functions via `wl-clipboard`.
- [`ClipboardQuickSettings.qml`](file:///home/jkikke/code/git/quickshell/ClipboardQuickSettings.qml) - iOS-style clipboard popover displaying active copy, history list, and one-click clear button.
- [`SettingsService.qml`](file:///home/jkikke/code/git/quickshell/SettingsService.qml) - Singleton service managing persistent user settings, automatic loading on start, and debounced saving to `settings.json`.
- [`SettingsView.qml`](file:///home/jkikke/code/git/quickshell/SettingsView.qml) - Morphed settings window inside the center pill with iOS-style toggles for 24h clock, seconds display, battery indicator, media view, top bar behavior, and dock settings.
- [`settings.json`](file:///home/jkikke/code/git/quickshell/settings.json) - JSON configuration file persisting user preferences across QuickShell restarts.
- [`SvgIcon.qml`](file:///home/jkikke/code/git/quickshell/SvgIcon.qml) - Scalable vector icons using `QtQuick.Shapes`.
- [`Theme.qml`](file:///home/jkikke/code/git/quickshell/Theme.qml) - Visual design tokens, dimensions, colors, and configuration.
- [`run.sh`](file:///home/jkikke/code/git/quickshell/run.sh) - Helper CLI runner for launching and testing.
