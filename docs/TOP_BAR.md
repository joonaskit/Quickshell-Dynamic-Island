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
- Places a `NotchEars` (`components/`) next to its body, which clips, to draw the curves into the edge. It is active with `Theme.notchEars`, which is off on glass, so the pill there just has a flat top.

## Tucked pills

With `tuckPills` on, the app tray and the virtual desktops sit half behind the status cluster and the window controls, and slide out while the pointer is over the part that shows. The state is `tabsEnabled`, `appTabTucked` and `desktopsTabTucked` in `island/IslandWindow.qml`.

## Top bar mode and auto-hide

`island/IslandWindow.qml` flattens the pills into the full-width bar (`isMaximized`) when a window is maximized or tiled, or always with `alwaysTopBar`, which suits tiling layouts. Fullscreen still hides everything.

Opened over the full bar, the island, the status cluster, the window controls and the tray grow out of it as one strip, or, on glass, open as separate cards below it (a test, `BarHang.detached`; see the end of this section). `components/BarHang.qml` does it for each: a pill puts one in, points it at its body, sets `body.gradient: hang.fill`, and lets its ears and `GlassSurface` follow `hang.hangs`. The body's fill is clear over the bar, so the bar shows through unchanged, then starts as the bar's own fill at its lower edge (`barFill`: `islandSurface` with the glass sheen there) and deepens to the body's own fill below it. The bar leaves out its lower edge, the glass rim and band, under each body (`TopBarWings.gaps`, from each pill's `barGap`; `edgeDepth`), notch ears (`NotchEars.inset`) in the bar's fill curve the body's sides into that edge, and the body draws no top band and no hairline. The ears are left out of the blur there (`earsBlur`), since a square blur below the bar shows as a clear patch beside the body. This all stays until the body has shrunk back to the bar. Gotchas, each found the hard way: the cut's top is on a whole device pixel and the fill starts one device pixel above it (`fillTop`), since the mask leaves the bar a pixel short and a gap shows as a light line; the gradient is always set and is the body's plain colour when not hanging, since a gradient set back to `null` leaves its last fill drawn; and the mask's thresholds are set by hand (see `TopBarWings.qml`), since the defaults leave `smoothstep` with equal edges.

On glass, as a test, `BarHang.detached` opens them as separate cards instead: the bar stays whole, the body is clear, and a `BarBubble` (`components/BarBubble.qml`) in the body draws a rounded card from `bubbleGap` below the bar, with its own `GlassSurface` and the window's blur (`blurBody`). The pill moves its menu down onto the card and adds that to its height while open (`bubbleOpen`): by the gap for the clusters, whose icons stay in the bar, and by the whole `bubbleTop` for the island and the tray, whose open content starts at the top. Set `detached` to false for the joined strip on glass too.

The window's `exclusiveZone` reserves `Theme.topBarHeight` while the full bar shows (`reserveSpaceWhenMaximized`). While it does not, `reserveSpaceWithoutBar` reserves `floatingGap`, the height of the floating pills, so tiled windows start below them. `hasTiledWindow` counts a window that starts below either reserved height as touching the top, so reserving space never flips the bar on and off.

With `autoHideTopBar` the whole bar slides up (`barHidden`, `barHideOffset` in `pillTopY`) and reserves no space. `barHoverArea` is a thin strip along the top edge while hidden; resting the pointer there for a moment brings the bar back, and it goes again shortly after the pointer leaves. Open menus and the expanded island keep it down. While it is down, pills with their own auto-hide (window controls, virtual desktops, app tray) are shown too (`barDown`).
