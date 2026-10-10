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

Six distinct patterns are used across the codebase:

| # | Pattern | Used for |
|---|---|---|
| **A** | Pill morph (width + height + radii) | All major popup clusters |
| **B** | Opacity crossfade | Content appearing inside an open popup |
| **C** | Y-translate slide off-screen | Auto-hide / fullscreen hide |
| **D** | Scale spring entrance | New floating elements appearing |
| **E** | Opacity-only fade | Simple menus and tooltips |
| **F** | Dock flyout (grow from the dock, morph between targets) | All popups attached to the dock |

---

## Pattern A — Pill Morph

The pill expands from its compact size to an open/menu size. `width` + `height` + all four corner radii animate simultaneously.

- **Open easing:** `Easing.OutBack`, overshoot `Theme.animOvershoot` (1.08) — bouncy spring
- **Close easing:** `Easing.OutCubic`, overshoot 1.0 — smooth collapse
- **Duration:** `Theme.animDuration` (360 ms) — or 260 ms in top-bar mode

### Instances

#### `IslandPill.qml` — Island Pill
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
| `IslandPill.qml` L221–302 | `compactClockView`, `compactMediaView`, `compactNotificationView`, `expandedView`, `notificationView`, `settingsView` | `isExpanded` / `isNotificationOpen` / `isSettingsOpen` / media state |
| `TopRightStatusCluster.qml` L736–863 | `menuContainer` + 9 individual sub-menus (WiFi, BT, Power, Clipboard, Notifications, Mic, Profile, Hardware, Devices) | `root.anyMenuOpen` + per-menu booleans |
| `TopRightStatusCluster.qml` L720–725 | Divider between status icons and menu content | `root.anyMenuOpen` |
| `TopLeftAppCluster.qml` L248–270 | `divider`, `menuContainer` | `root.menuOpen` |
| `AppIndicatorPill.qml` L435–589 | `compactContainer` (icon row), `morphedMenuArea` (context menu content) | `root.contextMenuOpen` |

The dock's popups (context menu, launcher, window list, downloads, trash) are not listed here: they use Pattern F.

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

#### Auto-Hide Proximity Glow (`HiddenElementGlow.qml`, `IslandWindow.qml` & `DockWindow.qml`)
When auto-hidden pills (`appCluster`, `virtualDesktopsPill`, `appIndicatorPill`) or the floating `DockBar` are retracted off-screen and the cursor approaches their edge trigger zones (top edge for status pills, bottom edge for the dock), an elegant multi-layer ambient glow illuminates the screen edge at the hidden element's location:
- **Entrance/Exit**: Fades in/out at `Theme.animDurationFast` (180 ms) with `Easing.OutCubic`.
- **Geometry tracking**: `Behavior on x` (360 ms `Easing.OutCubic`) & `Behavior on width` (360 ms `Theme.animEasing` with overshoot 1.08) dynamically tracking the element's horizontal footprint.
- **Top / Bottom Edge Adaptability**: `HiddenElementGlow.qml` supports bidirectional anchoring via `atBottom: true/false`, keeping diffuse glows, OLED core highlights, and specular beam gradients aligned to either screen bezel.
- **Ambient Luma Pulse**: Gentle infinite breathing sine-pulse between 0.70 and 1.00 (950 ms) while hovering.
- **Layering**: Layer 1 deep ambient colored halo (`RectangularGlow` with 38 px feathering & pill corner radius), Layer 2 OLED white diffuse glow (`RectangularGlow` with 16 px feathering), Layer 3 specular rounded edge beam (fully rounded pill with feathered ends), Layer 4 accent core pill.

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

### Desktop switch indicator

A virtual desktop switch shows in the island's OSD slot (the one volume and brightness use) for 1.5 s. `CompactOsdView.qml` draws one dot per desktop and the desktop's name. An accent highlight slides between the dots.

```qml
// The leading edge moves in 120 ms, the trailing edge in 220 ms, so the highlight stretches toward the new desktop
Behavior on leftEdge  { NumberAnimation { duration: movingRight ? 220 : 120; easing.type: Easing.OutCubic } }
Behavior on rightEdge { NumberAnimation { duration: movingRight ? 120 : 220; easing.type: Easing.OutCubic } }
```

- Rapid switches restart the hide timer and retarget the sliding highlight, so the indicator updates in place.
- It does not show for a click on the virtual desktops pill (`WindowService.pillSwitchUntil`), or over a fullscreen app, where the island is hidden.
- The setting is `showDesktopOsd`.

### Toggle switch knob slide (X axis)

```qml
x: isEnabled ? 22 : 2
Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
```

| File | Lines |
|---|---|
| `WifiQuickSettings.qml` | L126–128 |
| `BluetoothQuickSettings.qml` | L128–130 |
| `settings/SettingToggle.qml` | L107–109 |

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

## Pattern F — Dock Flyout

Every popup attached to the dock is an extension of the dock itself: its base lies on the dock's edge with no gap, and it grows out of the dock instead of fading in above it. The geometry lives in `dock/DockFlyoutGeometry.qml` and the body is drawn by `dock/DockFlyoutBackground.qml`. A popup binds its `x` / `y` / `width` / `height` to the geometry's outputs and puts the background behind its content.

### Open and close

One `progress` value (0 = closed, 1 = open) drives the whole shape:

```qml
property real progress: open ? 1.0 : 0.0
Behavior on progress {
    NumberAnimation {
        duration: geo.open ? Theme.animDuration : Theme.animDurationFast   // 360 ms in, 180 ms out
        easing.type: geo.open ? Theme.animEasing : Easing.OutCubic         // OutBack in, OutCubic out
        easing.overshoot: Theme.animOvershoot
    }
}
```

- **Along the dock** the body spreads from an icon-sized stub (`originSize`) to its final length.
- **Away from the dock** it grows from zero to its final depth.
- **The popup's opacity** reaches 1 in the first quarter of the animation (`progress * 4`).
- **Content** is laid out at its final size from the start and clipped by the body, so it is revealed rather than reflowed. It fades in over the last 60 % of the animation (`contentOpacity`).

### Retargeting an open popup

While a popup is on screen (`shown`, `progress > 0.001`), a change of origin or final size is animated instead of applied at once. This is what lets one context menu move from icon to icon, and one window list follow the pointer along the dock.

```qml
Behavior on origin      { enabled: geo.shown; NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic } }
Behavior on alongLength { enabled: geo.shown; NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic } }
Behavior on awayLength  { enabled: geo.shown; NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic } }
```

- **Slide and resize:** 260 ms `OutCubic`, no overshoot, so the body does not expose clipped content at the end of the move.
- **Content swap:** when the origin changes, the content is hidden at once, held for 70 ms, then faded back in over 200 ms (`swapFade`). The old content is never seen reflowing inside the moving body.
- **Closed popups jump.** The behaviors are disabled until the popup is shown, so opening always starts from the clicked icon, not from wherever the popup was last.
- The caller must keep the popup open while it retargets. `DockBar.toggleContextMenu` passes the menu to `closeAllPopups(except)` for this.
- A size change with the same origin (a window opening while the menu is up, the downloads list refreshing) is eased the same way, without the content fade.

### Alignment

`align` chooses where the popup sits along the dock:

| `align` | Position | Grows from | Used by |
|---|---|---|---|
| `"center"` (default) | Centred on the origin point, kept on the dock's straight edge. Centred on the dock if the dock is too short to carry it | The origin point (the clicked icon) | Context menu, window list, downloads |
| `"start"` | One side in line with the start end of the dock (left, or top for a vertical dock) | That corner of the dock | Launcher, launcher button menu |
| `"end"` | One side in line with the end of the dock (right, or bottom) | That corner of the dock | Trash menu |

With `"start"` and `"end"` the popup stays attached to that end of the dock and follows it, with the dock's own width animation, when icons are added or removed.

### Shape of the join

- **Centred popups** flare onto the dock with a concave fillet on each side (`filletSize`, 12 px). The fillets are dropped when the popup overhangs the dock's straight edge.
- **End-aligned popups** continue the end of the dock in one straight line. The dock straightens its corner under that side as the popup opens (`startCornerRadius` / `endCornerRadius` in `DockBar.qml`, reaching zero in the first third of the animation), so the two meet along a straight edge. While the corner still has some radius, the popup's outline runs down past its base and follows the corner, filling the wedge between the two.
- **The far side** of an end-aligned popup has a fillet while it rests on the dock's straight edge. The fillet shrinks to nothing as that side nears the dock's other rounded corner (`farFillet`), and if the side reaches past the dock, its base corner is rounded off instead (`farOverhang`).
- The body is slightly more opaque than the dock and fades to the exact dock colour at the base, so the join has no visible seam.
- The outline is one SVG path, drawn for a bottom dock with the flush side on the left, and rotated for left and right docks. Rotation puts that side at the top for a left dock and at the bottom for a right dock, so the path is mirrored whenever that is not the side that should be flush. The mirroring is done on the path's coordinates, not with a `Scale` transform, which would be applied after the rotation and flip the shape across the dock.
- **Pixel snapping.** The dock edge that popups attach to is snapped to the physical pixel grid (`snapToPixel`, `dockThickness` and `dockEdgeMargin` in `DockBar.qml`). With fractional display scaling a whole-number position usually falls between two physical pixels; the dock and the popup share that edge, and two half-covered translucent edges let the wallpaper through as a thin line. A curved join can never be snapped, which is why the dock's corner is straightened rather than only filled in.
- The background is centred in the popup with `anchors.alignWhenCentered: false`. With the default pixel snapping it can sit half a pixel off, which shows as a gap against a left or right dock.

### Hover

The background absorbs hover over the whole popup. The dock's magnification tracker reaches 16 px above the dock, under a popup's base; without this, hover falls through the gaps between a popup's own items and the dock icons twitch.

### Instances

| File | Popup | `align` |
|---|---|---|
| `DockContextMenu.qml` | App context menu | `"center"` |
| `DockWindowPicker.qml` | Hover window list | `"center"` |
| `DockDownloadsStack.qml` | Downloads stack | `"center"` |
| `DockAppPicker.qml` | Launcher | `"start"` |
| `DockLauncherMenu.qml` | Launcher button's right-click menu | `"start"` |
| `DockBar.qml` (`trashMenu`) | Trash menu | `"end"` |

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

Row 1 has since been superseded: the dock's context menu, launcher and trash menu no longer use a scale spring. They grow out of the dock as described under Pattern F.

### ⚠️ Intentionally Kept As-Is

| File | What | Reason |
|---|---|---|
| `TopBarWings.qml` | Uses `Easing.OutCubic` (not `OutBack`) for pill→bar morph | A full-width bar overshooting would look wrong; no spring intended |
| `DockItem.qml` L27 | `140` ms dock icon magnification scale | Part of a carefully tuned dock physics feel; changing would alter the magnification responsiveness |
| `DockItem.qml` L36–37 | `160` ms / `140` ms bounce keyframes | Fixed keyframe durations in a `SequentialAnimation`; semantically different from a `Behavior` |
| `AudioVisualizer.qml` | `250` / `260` / `300` ms waveform beat animations | Artistic timing tied to audio rhythm, not UI transitions |
| `BatteryIndicator.qml` | `300` ms battery fill | Deliberate slow fill effect |

