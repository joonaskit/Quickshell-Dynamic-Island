# Quickshell — Animation Catalogue

> Generated: 2026-09-28. Purpose: audit and unify open/close animations across all menus, popups, tooltips, and context windows.

---

## Global Theme Constants

All durations and easings are defined in `Theme.qml` and referenced throughout:

| Constant | Value | Usage |
|---|---|---|
| `Theme.animDuration` | **360 ms** | Pill morphs, slide transitions |
| `Theme.animDurationFast` | **180 ms** | Opacity crossfades, color fades |
| `Theme.animDurationTooltip` | **120 ms** | Tooltip fades, press/hover scale |
| `Theme.animDurationPopover` | **160 ms** | Popover X/Y repositioning slide |
| `Theme.animDurationTopBar` | **260 ms** | Top-bar mode height morph (tighter, no overshoot) |
| `Theme.animDurationProgress` | **300 ms** | Live progress bar fills |
| `Theme.animEasing` | `Easing.OutBack` | Opening easing (all pill morphs) |
| `Theme.animOvershoot` | **1.08** | Standard overshoot (pill morphs) |
| `Theme.animEntranceOvershoot` | **1.15** | Entrance overshoot (scale-from-zero) |

> [!NOTE]
> No `Transition {}`, `enter:`/`exit:` Popup properties, or `states:` state machines were found anywhere. Every animation is driven by a `Behavior {}` block reacting to a property binding change (typically an `isOpen` / `anyMenuOpen` / `shouldShow` boolean).

---

## Pattern Overview

Five distinct patterns are used across the codebase:

| # | Pattern | Used for |
|---|---|---|
| **A** | Pill morph (width + height + radii) | All major popup clusters |
| **B** | Opacity crossfade | Content appearing inside an open popup |
| **C** | Y-translate slide off-screen | Auto-hide / fullscreen hide |
| **D** | Scale spring entrance | New floating elements appearing |
| **E** | Opacity-only fade | Simple menus and tooltips |

---

## Pattern A — Pill Morph

The pill expands from its compact size to an open/menu size. `width` + `height` + all four corner radii animate simultaneously.

- **Open easing:** `Easing.OutBack`, overshoot `Theme.animOvershoot` (1.08) — bouncy spring
- **Close easing:** `Easing.OutCubic`, overshoot 1.0 — smooth collapse
- **Duration:** `Theme.animDuration` (360 ms) — or 260 ms in top-bar mode

### Instances

#### `IslandPill.qml` — Dynamic Island Pill
```qml
// Width
Behavior on width {
    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot }
}
// Height — easing differs by direction
Behavior on height {
    NumberAnimation {
        duration: Theme.animDuration
        easing.type: (root.isExpanded || root.isSettingsOpen) ? Theme.animEasing : Easing.OutCubic
        easing.overshoot: (root.isExpanded || root.isSettingsOpen) ? Theme.animOvershoot : 1.0
    }
}
// Corner radii (all four, same pattern)
Behavior on topLeftRadius     { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on topRightRadius    { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on bottomLeftRadius  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on bottomRightRadius { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
```
Trigger: `isExpanded` / `isSettingsOpen` booleans. Lines: 178–205.

---

#### `TopRightStatusCluster.qml` — Quick Settings Cluster
```qml
Behavior on width {
    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot }
}
Behavior on height {
    NumberAnimation {
        duration: root.isTopBarMode ? Theme.animDurationTopBar : Theme.animDuration
        easing.type: root.anyMenuOpen ? Theme.animEasing : Easing.OutCubic
        easing.overshoot: root.anyMenuOpen ? Theme.animOvershoot : 1.0
    }
}
Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
// + all four corner radii at 360ms / OutCubic
```
Trigger: `root.anyMenuOpen`. Lines: 260–288.

---

#### `TopLeftAppCluster.qml` — Window Controls + App Menu
```qml
Behavior on width {
    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot }
}
Behavior on height {
    NumberAnimation {
        duration: root.isTopBarMode ? Theme.animDurationTopBar : Theme.animDuration
        easing.type: root.menuOpen ? Theme.animEasing : Easing.OutCubic
        easing.overshoot: root.menuOpen ? Theme.animOvershoot : 1.0
    }
}
Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
// + all four corner radii at 360ms / OutCubic
```
Trigger: `root.menuOpen`. Lines: 132–159.

---

#### `AppIndicatorPill.qml` — System Tray Context Menu
```qml
Behavior on width {
    NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot }
}
Behavior on height {
    NumberAnimation {
        duration: Theme.animDuration
        easing.type: root.contextMenuOpen ? Theme.animEasing : Easing.OutCubic
        easing.overshoot: root.contextMenuOpen ? Theme.animOvershoot : 1.0
    }
}
Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
// + all four corner radii at 360ms / OutCubic
```
Trigger: `root.contextMenuOpen`. Lines: 400–427.

---

#### `VirtualDesktopsPill.qml` — Virtual Desktops Pill
```qml
Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot } }
Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on radius { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
```
Trigger: hover / menu open. Lines: 101–121.

---

#### `TopBarWings.qml` — Full-Width Top Bar (Maximized Window)

A structural morph from floating pill to a full-width bar. Uses `OutCubic` throughout (no overshoot).

```qml
Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on y      { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
// + all four corner radii (19 → 0) at 360ms / OutCubic
```
Trigger: `isMaximized`. Lines: 52–84.

---

## Pattern B — Opacity Crossfade (content inside open popup)

Content layers inside an already-open pill fade in/out at `Theme.animDurationFast` (180 ms) with no explicit easing (linear). The `visible: opacity > 0.01` guard is used to remove the item from the render tree after it fully fades out.

```qml
// Canonical pattern
opacity: someCondition ? 1.0 : 0.0
visible: opacity > 0.01           // optional, not always present
Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
```

### Instances

| File | Element | Trigger |
|---|---|---|
| `IslandPill.qml` L221–302 | `compactClockView`, `compactMediaView`, `compactNotificationView`, `expandedView`, `settingsView` | `isExpanded` / `isSettingsOpen` / media state |
| `TopRightStatusCluster.qml` L736–863 | `menuContainer` + 9 individual sub-menus (WiFi, BT, Power, Clipboard, Notifications, Mic, Profile, Hardware, Devices) | `root.anyMenuOpen` + per-menu booleans |
| `TopRightStatusCluster.qml` L720–725 | Divider between status icons and menu content | `root.anyMenuOpen` |
| `TopLeftAppCluster.qml` L248–270 | `divider`, `menuContainer` | `root.menuOpen` |
| `AppIndicatorPill.qml` L435–589 | `compactContainer` (icon row), `morphedMenuArea` (context menu content) | `root.contextMenuOpen` |
| `DockContextMenu.qml` L16–20 | Entire context menu | `isOpen` |
| `DockAppPicker.qml` L15–19 | Entire app picker | `isOpen` |
| `DockBar.qml` L443–447 | Trash context menu | `isOpen` |

#### Tooltip variants (120 ms, no easing)

Tooltips use a shorter 120 ms duration with no easing specified:

```qml
opacity: (isHovered && dockScale > 1.1) ? 1.0 : 0.0
visible: opacity > 0.01
Behavior on opacity { NumberAnimation { duration: 120 } }
```

| File | Element |
|---|---|
| `DockItem.qml` L139–144 | Dock icon tooltip |
| `DockBar.qml` L157–160, 370–373 | Launchpad and Trash button tooltips |
| `VirtualDesktopsPill.qml` L330 | Desktop hover tooltip (120 ms) |

#### Virtual desktops context menu popover (130 ms)
```qml
opacity: root.menuOpen ? 1.0 : 0.0
visible: opacity > 0.01
Behavior on opacity { NumberAnimation { duration: 130 } }
// Also slides on X to follow the clicked desktop:
Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
```
Lines: 379–383 in `VirtualDesktopsPill.qml`.

---

## Pattern C — Y-Translate Slide (auto-hide / fullscreen)

Panels slide off-screen along the Y axis (or use `bottomMargin`) when a fullscreen window is detected. Always `Easing.OutCubic` at full `Theme.animDuration` (360 ms).

### Instances

#### `DockWindow.qml` — Dock auto-hide
```qml
// Slide off below screen
anchors.bottomMargin: window.hasFullscreenApp ? (-height - 20) : Theme.dockBottomMargin
Behavior on anchors.bottomMargin {
    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
}
// Companion opacity fade (180ms)
opacity: window.hasFullscreenApp ? 0.0 : 1.0
Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
```
Lines: 81–91.

#### `IslandWindow.qml` — Multiple top-bar elements
All six elements (AppCluster, VirtualDesktopsPill, IslandPill, AppIndicatorPill, StatusCluster, TopBarWings) use the same Y-slide pattern with a companion opacity fade:

```qml
// Y slide — 360ms OutCubic
Behavior on y { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
// Opacity fade — 180ms
Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
```

| Element | Y-slide lines | Opacity lines |
|---|---|---|
| `appCluster` | L296–301 | L303 |
| `virtualDesktopsPill` | L333–338 | L340 |
| `islandPill` | L357–362 | L364 |
| `appIndicatorPill` | L415–420 | — |
| `statusCluster` | L481–486 | L488–490 |
| `topBarWings` | — | L264–266 |

#### Auto-Hide Proximity Glow (`HiddenElementGlow.qml` & `IslandWindow.qml`)
When auto-hidden pills (`appCluster`, `virtualDesktopsPill`, `appIndicatorPill`) are retracted off-screen and the cursor approaches their top-edge trigger zones, an elegant multi-layer ambient glow illuminates the edge above the hidden element:
- **Entrance/Exit**: Fades in/out at `Theme.animDurationFast` (180 ms) with `Easing.OutCubic`.
- **Geometry tracking**: `Behavior on x` (360 ms `Easing.OutCubic`) & `Behavior on width` (360 ms `Theme.animEasing` with overshoot 1.08) dynamically tracking the pill's footprint.
- **Ambient Luma Pulse**: Gentle infinite breathing sine-pulse between 0.70 and 1.00 (950 ms) while hovering.
- **Layering**: Layer 1 ambient colored halo (accent blue/cyan), Layer 2 OLED white diffuse glow, Layer 3 specular horizontal edge beam, Layer 4 accent core hairline.

---

## Pattern D — Scale Spring Entrance

New floating elements that appear from nothing use a scale-from-zero spring with a more pronounced overshoot (1.15–1.2) compared to the pill-morph overshoot (1.08). Always accompanied by a 180 ms opacity fade.

```qml
// Canonical pattern
scale: shouldShow ? 1.0 : 0.0
Behavior on scale {
    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
}
opacity: shouldShow ? 1.0 : 0.0
Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
```

### Instances

#### `AppIndicatorPill.qml` — Entire indicator pill appearing
```qml
scale: (root.isEnabled && root.appCount > 0 && !root.hasFullscreenApp) ? 1.0 : 0.0
Behavior on scale {
    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
}
```
Lines: 336–352.

#### `IslandDetachedBubble.qml` — Detached notification bubble
```qml
scale: shouldShow ? 1.0 : 0.0
Behavior on scale {
    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
}
```
Lines: 33–48. Also has a **hover size morph** (width + height 38→44, 360 ms, OutBack 1.08):
```qml
width: bubbleMouse.containsMouse ? Theme.px(44) : Theme.px(38)
Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot } }
```

#### `AppIndicatorPill.qml` — Floating tooltip badge (scale + opacity, 140 ms)
```qml
Behavior on opacity { NumberAnimation { duration: 140 } }
Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
```
Lines: 545–550.

---

## Pattern E — Miscellaneous / Interactive

Animations that aren't strictly open/close but are closely related and worth unifying.

### Press scale feedback (all interactive buttons)

Consistent pattern across all clickable elements:

```qml
scale: mouse.pressed ? 0.90 : 1.0
Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
```

| File | Element |
|---|---|
| `TopRightStatusCluster.qml` | All 10 status icon buttons |
| `AppIndicatorPill.qml` L462–467 | App icon buttons |
| `AppIndicatorPill.qml` L70–73 | Notification bubble body |
| `VirtualDesktopsPill.qml` L177–185 | Desktop item cards |

### Hover scale spring (menu items)

```qml
scale: mouse.pressed ? 0.98 : (mouse.containsMouse ? 1.02 : 1.0)
Behavior on scale {
    NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing; easing.overshoot: Theme.animOvershoot }
}
```

| File | Element |
|---|---|
| `TopLeftAppCluster.qml` L578–584 | All `MenuItem` components |
| `VirtualDesktopsPill.qml` L438–551 | Switch/Add/Remove desktop buttons |

### Dropdown chevron rotation

```qml
rotation: root.menuOpen ? 180 : 0
Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
```
File: `TopLeftAppCluster.qml` L220–224.

### Toggle switch knob slide (X axis)

```qml
x: isEnabled ? 22 : 2
Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
```

| File | Lines |
|---|---|
| `WifiQuickSettings.qml` | L126–128 |
| `BluetoothQuickSettings.qml` | L128–130 |
| `SettingsView.qml` | L1246–1247 |

### App launch bounce (dock icon)

```qml
SequentialAnimation {
    id: bounceAnim
    loops: 3
    NumberAnimation { target: root; property: "bounceOffset"; to: -22; duration: 200; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "bounceOffset"; to: 0;   duration: 180; easing.type: Easing.InQuad }
    NumberAnimation { target: root; property: "bounceOffset"; to: -12; duration: 160; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "bounceOffset"; to: 0;   duration: 140; easing.type: Easing.InQuad }
}
```
File: `DockItem.qml` L31–38. Total: ~1260 ms × 3 loops.

### Notification alert pulse (continuous)

```qml
SequentialAnimation on opacity {
    loops: Animation.Infinite
    NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
    NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
}
```
File: `CompactNotificationAlertView.qml` L81–85.

---

## Inconsistencies — Resolution Log

### ✅ Resolved

| # | File(s) | Was | Now |
|---|---|---|---|
| 1 | `DockContextMenu.qml`, `DockAppPicker.qml`, `DockBar.qml` (trash) | Opacity-only fade — no entrance character | Added `scale: isOpen ? 1.0 : 0.92` + `Behavior on scale` with `OutBack`/`animEntranceOvershoot` spring, `transformOrigin: Item.Bottom` |
| 2 | Tooltip opacity fades (DockBar, DockItem, VirtualDesktopsPill) | Hardcoded `120` ms | `Theme.animDurationTooltip` |
| 3 | VirtualDesktopsPill context menu opacity | Hardcoded `130` ms | `Theme.animDurationTooltip` |
| 4 | VirtualDesktopsPill tooltip + popover X-slide | Hardcoded `140` / `160` ms | `Theme.animDurationPopover` |
| 5 | AppIndicatorPill floating tooltip opacity + scale | Hardcoded `140` ms, overshoot `1.2` | `Theme.animDurationTooltip`, `Theme.animEntranceOvershoot` |
| 6 | AppIndicatorPill + IslandDetachedBubble entrance overshoot | Hardcoded `1.15` | `Theme.animEntranceOvershoot` |
| 7 | `HardwareStatsQuickSettings.qml` progress bar | Hardcoded `300` ms | `Theme.animDurationProgress` |
| 8 | `SettingsView.qml` scroll fade indicator | Hardcoded `250` ms | `Theme.animDurationFast` |
| 9 | `TopLeftAppCluster.qml` + `TopRightStatusCluster.qml` top-bar height | Hardcoded `260` ms | `Theme.animDurationTopBar` |
| 10 | `TopLeftAppCluster.qml` chevron rotation | Hardcoded `180` ms | `Theme.animDurationFast` |
| 11 | `TopLeftAppCluster.qml` divider fade | Hardcoded `140` ms | `Theme.animDurationFast` |
| 12 | `TopRightStatusCluster.qml` button press scale (×10) | Hardcoded `120` ms | `Theme.animDurationTooltip` |
| 13 | `TopRightStatusCluster.qml` icon color fades (×10) | Hardcoded `140` ms | `Theme.animDurationFast` |
| 14 | `ExpandedView.qml` settings gear scale + color | Hardcoded `140` ms | `Theme.animDurationTooltip` / `Theme.animDurationFast` |
| 15 | `DeviceQuickSettings.qml` color fades | Hardcoded `140` ms | `Theme.animDurationFast` |
| 16 | `VirtualDesktopsPill.qml` desktop item + add-button scales | Hardcoded `120` ms | `Theme.animDurationTooltip` |
| 17 | `PowerProfileQuickSettings.qml` checkmarks & icon/text colors | Snap changes (`visible: boolean`) | `opacity` + `scale` spring (`Theme.animEntranceOvershoot`) + `Behavior on color` |
| 18 | `MicrophoneQuickSettings.qml` input device section & checkmark | Snap changes (`visible: boolean`) | `opacity` fade on container, `opacity` + `scale` spring on checkmark, color transitions |
| 19 | `WifiQuickSettings.qml` & `BluetoothQuickSettings.qml` states | Abrupt `visible` toggles on empty/disabled states and connection checkmarks | `opacity` fade on state texts & devices section, `opacity` + `scale` spring on active checkmarks |
| 20 | `NotificationListView.qml` card entrance & empty state | Static card creation & abrupt empty state | Spring entrance animation (`Component.onCompleted`) on notification card, `opacity` fade on empty state |
| 21 | `IslandPill.qml` crossfade views (Clock, Media, Notif, Expanded, Settings) | Flat 2D opacity-only crossfade | Added depth with `scale: opacity > 0.5 ? 1.0 : 0.94` (compact) / `0.97` (expanded) + `Behavior on scale` |
| 22 | `SettingsView.qml` header Back/Close buttons & grabber | No press scale feedback | Added `scale` + `Behavior on scale` (`Theme.animDurationTooltip`), standardized colors |
| 23 | `SettingsView.qml` slider track, knob & presets | Instant snap on preset select / external update | Added `Behavior on x` & `Behavior on width` (`Theme.animDurationPopover`, enabled when not dragging), knob scale on hover/drag, glow opacity fade, preset button scale |
| 24 | `ClipboardQuickSettings.qml` Empty button, history list & delete buttons | Abrupt visibility toggles, no button scale | Added `scale` + `Behavior on scale` to empty/delete buttons, `opacity` fade on recent copies section |

### ⚠️ Intentionally Kept As-Is

| File | What | Reason |
|---|---|---|
| `TopBarWings.qml` | Uses `Easing.OutCubic` (not `OutBack`) for pill→bar morph | A full-width bar overshooting would look wrong; no spring intended |
| `DockItem.qml` L27 | `140` ms dock icon magnification scale | Part of a carefully tuned dock physics feel; changing would alter the magnification responsiveness |
| `DockItem.qml` L36–37 | `160` ms / `140` ms bounce keyframes | Fixed keyframe durations in a `SequentialAnimation`; semantically different from a `Behavior` |
| `AudioVisualizer.qml` | `250` / `260` / `300` ms waveform beat animations | Artistic timing tied to audio rhythm, not UI transitions |
| `IPhoneBattery.qml` | `300` ms battery fill | Deliberate slow fill effect |

