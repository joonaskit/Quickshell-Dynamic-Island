# Top bar

The pills along the top edge: the island, the status cluster on the right, the window controls and app tray on the left, and the virtual desktops. Their animations are in `ANIMATION_CATALOGUE.md`.

## Status icons

`island/StatusIconRegistry.qml` lists the top-right status icons in their default order. The user's order is `statusIconOrder` in `settings.json`.

A new icon needs:

- An entry in `StatusIconRegistry.qml`, with a `title` and `description` for its settings row. An icon that shows only when needed also has a `pinKey`, the setting that keeps it shown; its row is then an Off / When Needed / Always choice.
- A button component in `island/TopRightStatusCluster.qml` under the same id, in `iconComponents` and `isIconShown`.

## Pill style

The `pillStyle` setting (`Theme.notchStyle`) makes the top pills hug the screen edge. Each top pill does three things, and a new one needs the same:

- Rests at `IslandWindow.pillTopY`.
- Returns a flat top radius and `Theme.notchRadius` at the bottom.
- Places a `NotchEars` (`components/`) next to its body, which clips, to draw the curves into the edge.

## Tucked pills

With `tuckPills` on, the app tray and the virtual desktops sit half behind the status cluster and the window controls, and slide out while the pointer is over the part that shows. The state is `tabsEnabled`, `appTabTucked` and `desktopsTabTucked` in `island/IslandWindow.qml`.

## Top bar mode and auto-hide

`island/IslandWindow.qml` flattens the pills into the full-width bar (`isMaximized`) when a window is maximized or tiled, or always with `alwaysTopBar`, which suits tiling layouts. Fullscreen still hides everything.

The window's `exclusiveZone` reserves `Theme.topBarHeight` while the full bar shows (`reserveSpaceWhenMaximized`). While it does not, `reserveSpaceWithoutBar` reserves `floatingGap`, the height of the floating pills, so tiled windows start below them. `hasTiledWindow` counts a window that starts below either reserved height as touching the top, so reserving space never flips the bar on and off.

With `autoHideTopBar` the whole bar slides up (`barHidden`, `barHideOffset` in `pillTopY`) and reserves no space. `barHoverArea` is a thin strip along the top edge while hidden; resting the pointer there for a moment brings the bar back, and it goes again shortly after the pointer leaves. Open menus and the expanded island keep it down. While it is down, pills with their own auto-hide (window controls, virtual desktops, app tray) are shown too (`barDown`).
