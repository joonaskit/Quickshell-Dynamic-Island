# Glass look

The **Glass** style (Settings → Appearance → Colors → Style, `shellStyle` in `settings.json`) draws the island, its side pills, the dock, the dock's popups and the launcher as frosted glass, as on macOS and iOS. It works with either appearance: white glass on light, smoked glass on dark. **Solid**, the default, is OLED black on dark and warm paper on light.

The style is `Theme.style`, and `Theme.glass` is true in the glass style. The appearance (`Theme.scheme`) still picks light or dark, and only it reaches KDE apps and `theme.json`, so dark KDE apps under a glass shell is Dark + Glass.

The dock used to have a glass look of its own (`dockTransparent`). The style replaces it: an older config with that on loads as Glass. The dock keeps its two opacities, `dockOpacity` for Solid and `dockGlassOpacity` for Glass.

## Pieces

- **Fill.** `Theme.islandSurface` for pill bodies and `Theme.menuSurface` for open menus, the expanded island and the centred launcher: translucent in the glass style (`glassFill`, `glassFillStrong`: white on light, near black on dark), else `islandBackground`. The side pills keep `pillFrosted`, which is `glassFill` on glass. On glass, `islandBorder` is a hairline (`glassHairline`) that parts the pill from the background: dark on light, light on dark.
- **Dock.** The dock's default tint on light glass is the `glassFill` colour, and on dark glass a slightly blue near black, at the glass opacity set in the Dock settings. Its popups use `Theme.dockPopupAlpha`, which drops to the `glassFillStrong` opacity on blurred glass.
- **Cards and controls.** Inside the island, its menus and the dock, use `Theme.cardSurface` and `cardSurfaceHover` for cards, round buttons and hovered rows, `raisedSurface` for tooltips and the rings round badges, and `controlTrack` and `controlTrackOff` for slider and switch tracks. In the solid style they are the opaque roles (`cardBackground`, `sliderTrack`, ...). On glass the cards are white tints, whiter on hover, that let the glass through, and the tracks are neutral tints (`overlayNeutral`), not the light scheme's paper tones. Tooltips float over anything and are never blurred, so `raisedSurface` is near opaque.
- **Text.** On dark glass `textSecondary` and `textTertiary` are a step brighter, since the grey behind them shows through. `theme.json` and the KDE scheme take `textSecondaryBase` and `textTertiaryBase`, which follow the appearance only.
- **Status colours.** The plain `accentOrange`, `accentYellow`, `accentGreen` and `accentCyan` are too pale for text and icons on a light background. Use the `*Strong` versions for those (`accentOrangeStrong`, `accentYellowStrong`, `accentGreenStrong`, `accentCyanStrong`, `accentRedStrong`); they are deeper on light and the plain colour on dark. Fills such as bars, dots, switch tracks, glows and tints keep the plain colour.
- **Light.** `components/GlassSurface.qml` goes inside a body, before its content, with `body` pointing at it. It draws a sheen lit from above, and a rim that is bright along the top and bottom edges with a softer band inside it, for the thickness of the glass. Its colours are Theme roles (`glassRimTop`, `glassSheen`, `glassBandTop`, ...), much fainter on dark, where a bright rim would glare. It follows the body's size and corner radii, and hides when the body is clear (`color` with no alpha, as in top-bar mode). The dock's popups (`DockFlyoutBackground`) draw the same light themselves, since their outline is a path with fillets onto the dock, not a Rectangle: the sheen fills the outline, and the rim and band are rings of a rectangle rounded at the top, which the outline is above its fillets. They fade out before the base, where the popup joins the dock. On a left or right dock the popup is rotated, so its light comes from the edge away from the dock.
- **Notch style.** A pill that hangs from the top edge has notch ears (`NotchEars`) beside it, separate shapes in the body's fill. On glass the body then draws no border: `GlassSurface` with `flushTop` draws the hairline itself, starting below the ears, and the ears draw it along their curves, so one outline runs from the screen edge round the ears and down the body. The rim and sheen also leave the top out, where the ears join. The ears are in the blur too; their blur is square, so the small corner outside each curve is blurred without fill.
- **Blur.** `components/WindowBlur.qml` blurs the desktop behind a window's pills and popups. Give it the window as `target` and the bodies as `items`, once. An entry is a Rectangle, which lends its corner radii, or `{ item, topLeftRadius, ... }` for an item without them: `DockBar.flyoutBlur` builds those for the dock's popups, rounded on the corners away from the dock.

`islandBackground`, `cardBackground` and the slider and switch tracks stay opaque in both styles, paper toned on light: `theme.json`, the KDE colour scheme and the standalone windows (settings, clipboard, welcome guide) use them.

### How the blur follows the pills

A Quickshell `Region` with an `item` updates only when that item's own position or size changes, not when a parent moves it (a pill sliding up to hide) or a transform shifts it (the dock dropping off screen). So `WindowBlur` gives each region a plain rectangle instead, and after every frame that animates (`afterAnimating` of the window) moves it to where its item is drawn. It assigns only what changed, since each change makes the window draw another frame. An item drops out of the blur while it, or a parent, is hidden or faded out.

## Blur needs Quickshell 0.3

The blur uses Quickshell's `BackgroundEffect` (the `ext-background-effect-v1` protocol), and rounded `Region`s, which both came with Quickshell 0.3. KWin 6.7 supports the protocol.

At startup `Theme` compiles a window that uses both, without creating it, and sets `Theme.blurAvailable`. `WindowBlur` builds its effect from a string at runtime for the same reason: the shell still loads, and `./lint.sh` still passes, on Quickshell 0.2.

Without the blur the fills are more opaque (`glassFill` 0.84 instead of 0.6 on light, 0.84 instead of 0.55 on dark), and on light a neutral grey instead of white, so text stays readable over a sharp background and the white rim still shows. A compositor without the protocol gives the clearer fill with no blur behind it.

## Not covered yet

- The blur behind the dock's popups is a rounded rectangle, so the small fillets onto the dock have no blur.