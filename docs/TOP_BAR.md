# Top bar

The pills along the top edge: the island, the status cluster on the right, the window controls and app tray on the left, and the virtual desktops. Their animations are in `ANIMATION_CATALOGUE.md`.

## Status icons

`island/StatusIconRegistry.qml` lists the top-right status icons in their default order. The user's order is `statusIconOrder` in `settings.json`.

A new icon needs:

- An entry in `StatusIconRegistry.qml`.
- A button component in `island/TopRightStatusCluster.qml` under the same id, in `iconComponents` and `isIconShown`.

## Pill style

The `pillStyle` setting (`Theme.notchStyle`) makes the top pills hug the screen edge. Each top pill does three things, and a new one needs the same:

- Rests at `IslandWindow.pillTopY`.
- Returns a flat top radius and `Theme.notchRadius` at the bottom.
- Places a `NotchEars` (`components/`) next to its body, which clips, to draw the curves into the edge.

## Tucked pills

With `tuckPills` on, the app tray and the virtual desktops sit half behind the status cluster and the window controls, and slide out while the pointer is over the part that shows. The state is `tabsEnabled`, `appTabTucked` and `desktopsTabTucked` in `island/IslandWindow.qml`.
