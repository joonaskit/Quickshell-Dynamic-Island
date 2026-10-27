pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // Color scheme: "dark" or "light" (SettingsService.colorScheme). Every role
    // below has a value for each, and overlay() flips with it.
    property string scheme: "dark"
    readonly property bool isLight: scheme === "light"
    // Shell style: "solid" or "glass" (SettingsService.shellStyle), on either scheme.
    // It changes only the island, the dock, the launcher and their menus.
    property string style: "solid"

    // A translucent layer for hovers, dividers, borders and dimmed text: white on
    // the dark scheme, black on the light one. Use this instead of a literal
    // Qt.rgba(1, 1, 1, alpha), which only works on a dark background.
    function overlay(alpha) {
        // A warm near-black on light, to sit with the warm paper tones below
        return isLight ? Qt.rgba(0.14, 0.11, 0.07, alpha) : Qt.rgba(1, 1, 1, alpha);
    }

    // overlay() without the warm cast of the light scheme, for glass
    function overlayNeutral(alpha) {
        return isLight ? Qt.rgba(0, 0, 0, alpha) : Qt.rgba(1, 1, 1, alpha);
    }

    // OLED true black and sleek translucent border. Opaque on both schemes: theme.json,
    // the KDE scheme and the standalone windows use it. The island itself draws
    // islandSurface, which is glass in the glass style.
    readonly property color islandBackground: isLight ? "#faf6ef" : "#000000"
    readonly property color islandBorder: glass ? glassHairline : Qt.rgba(1, 1, 1, 0)
    // Frosted glass for the quieter side pills (virtual desktops, app tray)
    readonly property color pillFrosted: glass ? glassFill : (isLight ? Qt.rgba(0.97, 0.95, 0.92, 0.8) : Qt.rgba(0.12, 0.12, 0.14, 0.65))
    readonly property color pillFrostedBorder: glass ? glassHairline : overlay(0.09)
    readonly property color islandBorderHover: glass ? glassHairline : Qt.rgba(1, 1, 1, 0)

    // The glass style is frosted glass, as on macOS and iOS, white on light and smoked
    // on dark: the island and its side pills draw a translucent fill, and GlassSurface adds a top-lit sheen and a rim that
    // catches the light on the top and bottom edges. With Quickshell 0.3 or later
    // (blurAvailable), WindowBlur also blurs the desktop behind them, so the fill can be
    // clearer; without it the fill stays milky enough to read over a sharp background.
    readonly property bool glass: style === "glass"
    property bool blurAvailable: false
    // Opacity of the glass (SettingsService.glassOpacity, glassMenuOpacity): the island
    // and its pills, and the menus, popups and launcher, which carry more text
    property real glassOpacity: 0.6
    property real glassMenuOpacity: 0.8
    // Without blur a sharp background shows through, so the same setting gives a
    // more opaque fill: 60% becomes 84%
    function glassAlpha(opacity) {
        return blurAvailable ? opacity : opacity + (1 - opacity) * 0.6;
    }
    // Without blur the fill is a neutral grey rather than white: white over a sharp
    // background reads as a flat white panel, not glass, and the white rim needs a
    // darker body to show against
    readonly property color glassFill: isLight
        ? (blurAvailable ? Qt.rgba(0.965, 0.965, 0.975, glassAlpha(glassOpacity)) : Qt.rgba(0.87, 0.87, 0.885, glassAlpha(glassOpacity)))
        : (blurAvailable ? Qt.rgba(0.11, 0.11, 0.13, glassAlpha(glassOpacity)) : Qt.rgba(0.10, 0.10, 0.12, glassAlpha(glassOpacity)))
    // Open menus, the expanded island, the launcher and the dock's popups
    readonly property color glassFillStrong: isLight
        ? (blurAvailable ? Qt.rgba(0.975, 0.975, 0.98, glassAlpha(glassMenuOpacity)) : Qt.rgba(0.91, 0.91, 0.92, glassAlpha(glassMenuOpacity)))
        : (blurAvailable ? Qt.rgba(0.10, 0.10, 0.12, glassAlpha(glassMenuOpacity)) : Qt.rgba(0.09, 0.09, 0.11, glassAlpha(glassMenuOpacity)))
    // Dark on light, to part the glass from a light background; light on dark
    readonly property color glassHairline: isLight ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.1)
    // The light on the glass (GlassSurface): much fainter on dark, where a bright rim
    // would glare
    readonly property color glassRimTop: Qt.rgba(1, 1, 1, isLight ? 0.95 : 0.3)
    readonly property color glassRimSide: Qt.rgba(1, 1, 1, isLight ? 0.22 : 0.06)
    readonly property color glassRimBottom: Qt.rgba(1, 1, 1, isLight ? 0.6 : 0.14)
    // On dark the sheen stays faint: it lifts the top of a body, where headers and
    // grey labels sit, towards their own grey
    readonly property color glassSheen: Qt.rgba(1, 1, 1, isLight ? 0.38 : 0.035)
    readonly property color glassSheenLow: Qt.rgba(1, 1, 1, isLight ? 0.06 : 0.02)
    // The softer band inside the rim, top and bottom
    readonly property color glassBandTop: Qt.rgba(1, 1, 1, isLight ? 0.3 : 0.06)
    readonly property color glassBandBottom: Qt.rgba(1, 1, 1, isLight ? 0.18 : 0.04)
    // The island's body and its open menus: glass in the glass style, else opaque
    readonly property color islandSurface: glass ? glassFill : islandBackground
    readonly property color menuSurface: glass ? glassFillStrong : islandBackground
    readonly property color islandShadow: Qt.rgba(0, 0, 0, 0)

    // Inner card backgrounds & subtle highlights
    readonly property color cardBackground: isLight ? "#f1ebe1" : "#1c1c1e"
    readonly property color cardBackgroundHover: isLight ? "#e7dfd2" : "#2c2c2e"
    // The cards above inside the island, its menus and the dock. On glass they are
    // white tints that let the glass through, not opaque tones; the hover is whiter.
    readonly property color cardSurface: glass ? Qt.rgba(1, 1, 1, isLight ? 0.5 : 0.07) : cardBackground
    readonly property color cardSurfaceHover: glass ? Qt.rgba(1, 1, 1, isLight ? 0.78 : 0.13) : cardBackgroundHover
    // Tooltips and the rings round badges: small, over anything and never blurred, so
    // near opaque on glass
    readonly property color raisedSurface: glass ? (isLight ? Qt.rgba(0.975, 0.975, 0.98, 0.97) : Qt.rgba(0.13, 0.13, 0.15, 0.97)) : cardBackground
    // Gradient of the dock's fallback letter tile
    readonly property color tileGradientTop: isLight ? "#e7dfd2" : "#3a3a3c"
    readonly property color tileGradientBottom: isLight ? "#d9d0c2" : "#242426"
    readonly property color controlBackground: Qt.rgba(1, 1, 1, 0)
    readonly property color controlBackgroundHover: Qt.rgba(1, 1, 1, 0)
    readonly property color controlBackgroundActive: Qt.rgba(1, 1, 1, 0)

    // Text colors (standard label hierarchy)
    // On light, secondary and tertiary are darker than a mirror of the dark values
    // would give: tertiary carries real text (descriptions), and light grey on a
    // light background is much harder to read than dark grey on black
    readonly property color textPrimary: isLight ? "#221f1a" : "#ffffff"
    // A step brighter on dark glass, where the grey shows through behind them.
    // theme.json and the KDE scheme follow the appearance only, so they take the
    // *Base values.
    readonly property color textSecondaryBase: isLight ? "#575147" : "#98989d"
    readonly property color textTertiaryBase: isLight ? "#787166" : "#636366"
    readonly property color textSecondary: (glass && !isLight) ? "#b4b4b9" : textSecondaryBase
    readonly property color textTertiary: (glass && !isLight) ? "#88888d" : textTertiaryBase
    // Foreground on a strong overlay() fill, such as the play button: the fill is
    // near-white on the dark scheme and near-black on the light one
    readonly property color lightForeground: isLight ? "#ffffff" : "#000000"
    // Foreground on red fills such as unread badges
    readonly property color dangerForeground: "#ffffff"

    // Accent colors
    readonly property color accentGreen: "#30d158"
    // Green for icons and text on the panel background; fills keep the plain one.
    // The same goes for the other *Strong colours below.
    readonly property color accentGreenStrong: isLight ? "#1e8236" : accentGreen
    readonly property color accentBlue: "#0a84ff"
    readonly property color accentOrange: "#ff9f0a"
    // Orange for icons and text on the panel background: the plain orange washes out
    // on light glass. Fills (bars, dots, tints) keep the plain one.
    readonly property color accentOrangeStrong: isLight ? "#b85500" : accentOrange
    readonly property color accentYellow: "#ffd60a"
    // Yellow for icons and text on the panel background: the plain yellow washes out on light
    readonly property color accentYellowStrong: isLight ? "#9a7000" : accentYellow
    readonly property color accentRed: "#ff453a"
    // Red for text and icons on a light panel, where the plain red is too weak
    readonly property color accentRedStrong: isLight ? "#d70015" : accentRed
    readonly property color accentPurple: "#bf5af2"
    readonly property color accentCyan: "#64d2ff"
    readonly property color accentCyanStrong: isLight ? "#0077a8" : accentCyan
    readonly property color accentIndigo: "#5e5ce6"

    // The user's accent: selection, focus and active states. Chosen by name from
    // accentChoices (SettingsService.accentColor). The accent* colors above keep
    // their own meaning as category and status colors and do not follow it.
    property string accentName: "blue"
    readonly property var accentChoices: [
        { "name": "blue", "label": "Blue", "color": accentBlue },
        { "name": "indigo", "label": "Indigo", "color": accentIndigo },
        { "name": "purple", "label": "Purple", "color": accentPurple },
        { "name": "red", "label": "Red", "color": accentRed },
        { "name": "orange", "label": "Orange", "color": accentOrange },
        { "name": "yellow", "label": "Yellow", "color": accentYellow },
        { "name": "green", "label": "Green", "color": accentGreen },
        { "name": "cyan", "label": "Cyan", "color": accentCyan }
    ]
    readonly property color accent: {
        for (let i = 0; i < accentChoices.length; i++) {
            if (accentChoices[i].name === accentName) return accentChoices[i].color;
        }
        return accentBlue;
    }
    // Text and icons on top of an accent fill: black on the light accents
    // (orange, yellow, green, cyan), white on the others.
    // These roles are not named "onAccent" etc. on purpose: QML reads a binding
    // to a name of the form on<Capital> as a signal handler and silently drops it.
    readonly property color accentForeground: (0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b) > 0.6 ? "#000000" : "#ffffff"

    // The accent for text and icons on a tint of itself or a grey: darkened on the
    // light scheme, where the plain accent washes out, and lightened on dark glass,
    // where the grey behind it dulls it
    readonly property color accentText: isLight ? Qt.darker(accent, 1.7) : (glass ? Qt.tint(accent, Qt.rgba(1, 1, 1, 0.4)) : accent)

    // The accent at a given opacity, for selection fills and focus borders
    function accentTint(alpha) {
        return Qt.rgba(accent.r, accent.g, accent.b, alpha);
    }

    // Slider styling
    readonly property color sliderTrack: isLight ? "#d9d0c2" : "#3a3a3c"
    readonly property color sliderFill: isLight ? "#221f1a" : "#ffffff"
    readonly property color sliderHandle: "#ffffff"
    readonly property color switchTrackOff: isLight ? "#d3c9b9" : "#39393d"
    // The two above on glass: neutral tints that let the glass through. The settings
    // window, which is not glass, keeps them.
    readonly property color controlTrack: glass ? overlayNeutral(isLight ? 0.1 : 0.16) : sliderTrack
    readonly property color controlTrackOff: glass ? overlayNeutral(isLight ? 0.13 : 0.2) : switchTrackOff

    // Fonts. The user's choices (SettingsService.fontFamily / fontDisplayFamily) are
    // family names, empty for the defaults. The fonts always fall back to the
    // defaults, so a missing or misspelled choice still gives readable text.
    property string fontFamilyChoice: ""
    property string fontDisplayChoice: ""
    readonly property var fontDefaults: ["Cantarell", "Noto Sans", "Liberation Sans"]
    readonly property var installedFonts: Qt.fontFamilies()

    // A family name for font.family: the first of the choice and the defaults that
    // is installed. font.family takes one name, not a fallback list.
    function resolveFont(choice) {
        let candidates = choice !== "" ? [choice].concat(fontDefaults) : fontDefaults;
        if (installedFonts.length === 0) return candidates.join(", ");
        for (let i = 0; i < candidates.length; i++) {
            if (installedFonts.indexOf(candidates[i]) >= 0) return candidates[i];
        }
        return "sans-serif";
    }

    readonly property string fontFamily: resolveFont(fontFamilyChoice)
    // Large and numeric text; follows the interface font unless set separately
    readonly property string fontDisplay: fontDisplayChoice !== "" ? resolveFont(fontDisplayChoice) : fontFamily
    // The same fonts as a fallback list, exported to companion apps
    readonly property string fontFamilyList: (fontFamilyChoice !== "" ? fontFamilyChoice + ", " : "") + fontDefaults.join(", ") + ", sans-serif"
    readonly property string fontDisplayList: fontDisplayChoice !== "" ? fontDisplayChoice + ", " + fontFamilyList : fontFamilyList

    // Corner roundness (SettingsService.cornerStyle). Panels, cards, buttons and rows
    // scale their style radii by cornerScale: use corner(n) for an unscaled radius and
    // cornerPx(n) for one that follows the interface scale. Shapes (pills, circles,
    // bars and dots, where the radius is half the size) keep a plain number.
    property string cornerStyle: "default"
    // The corner radius of the KDE style in use (Kirigami.Units.cornerRadius). Kirigami
    // is loaded at runtime so the shell still starts without it, and then reports 5,
    // the radius of Breeze.
    property real kdeCornerRadius: 5
    property var kdeCornerProbe: null

    Component.onCompleted: {
        try {
            theme.kdeCornerProbe = Qt.createQmlObject(
                'import QtQuick; import org.kde.kirigami as Kirigami; QtObject { property real value: Kirigami.Units.cornerRadius }',
                theme, "KdeCornerProbe");
            theme.kdeCornerRadius = theme.kdeCornerProbe.value;
            theme.kdeCornerProbe.valueChanged.connect(() => { theme.kdeCornerRadius = theme.kdeCornerProbe.value; });
        } catch (e) {
            console.warn("Theme: Kirigami not available, using a 5px KDE corner radius");
        }
        // BackgroundEffect and rounded Regions came with Quickshell 0.3. The probe only
        // compiles a window that uses them, it never creates one.
        try {
            let blurProbe = Qt.createQmlObject(
                'import QtQuick; import Quickshell; import Quickshell.Wayland; QtObject { property Component window: Component { PanelWindow { BackgroundEffect.blurRegion: Region { radius: 1 } } } }',
                theme, "BlurProbe");
            blurProbe.destroy();
            theme.blurAvailable = true;
        } catch (e) {
            console.info("Theme: this Quickshell has no BackgroundEffect (0.3 and later), glass is drawn without blur");
        }
    }

    readonly property var cornerChoices: [
        { "name": "square", "label": "Square", "scale": 0.2 },
        // The radius of the KDE style in use: Breeze's own widgets use 5px, which is
        // corner(10) at half
        { "name": "kde", "label": "KDE", "scale": kdeCornerRadius / 10 },
        { "name": "tight", "label": "Tight", "scale": 0.6 },
        { "name": "default", "label": "Default", "scale": 1.0 },
        { "name": "round", "label": "Round", "scale": 1.5 }
    ]
    readonly property real cornerScale: {
        for (let i = 0; i < cornerChoices.length; i++) {
            if (cornerChoices[i].name === cornerStyle) return cornerChoices[i].scale;
        }
        return 1.0;
    }
    // The island's expanded view and the dock follow the setting half as much, so
    // they keep their identity at the extremes
    readonly property real cornerScaleSoft: 1.0 + (cornerScale - 1.0) * 0.5

    function corner(base) {
        return base * cornerScale;
    }

    function cornerPx(base) {
        return px(base) * cornerScale;
    }

    // Pill style (SettingsService.pillStyle): "floating" pills hang below the top edge,
    // "notch" pills hug it with a flat top and soft curves (NotchEars) flaring into the
    // screen edge. The maximised top bar is unaffected.
    property string pillStyle: "floating"
    readonly property bool notchStyle: pillStyle === "notch"
    property int notchEar: px(10)
    // Bottom corners of a compact pill in notch style
    property int notchRadius: px(14)

    // Corner radius scale (unscaled), exported to companion apps
    readonly property int radiusSmall: Math.round(corner(6))
    readonly property int radiusMedium: Math.round(corner(10))
    readonly property int radiusLarge: Math.round(corner(14))

    // UI Scaling & DPI (limits: 0.80 to 1.25)
    property real uiScale: 1.0
    property real fontScale: 1.0

    // Scaling helpers
    function px(base) {
        return Math.round(base * uiScale);
    }

    function fontPx(base) {
        return Math.max(8, Math.round(base * fontScale * uiScale));
    }

    // Base dimensions (unscaled reference)
    readonly property int baseTopMargin: 10
    readonly property int baseCompactWidthClock: 154
    readonly property int baseCompactWidthMedia: 228
    readonly property int baseCompactHeight: 38
    readonly property int baseCompactRadius: 19

    readonly property int baseExpandedWidth: 410
    readonly property int baseExpandedHeight: 180
    readonly property int baseExpandedHeightWithMedia: 236
    readonly property int baseExpandedRadius: 28

    readonly property int baseTopBarHeight: 34
    readonly property int baseDockHeight: 64
    readonly property int baseDockRadius: 20
    readonly property int baseDockBottomMargin: 12

    // Dynamically scaled dimensions
    property int topMargin: px(baseTopMargin)
    property int compactWidthClock: px(baseCompactWidthClock)
    property int compactWidthMedia: px(baseCompactWidthMedia)
    property int compactHeight: px(baseCompactHeight)
    property int compactRadius: px(baseCompactRadius)

    property int expandedWidth: px(baseExpandedWidth)
    property int expandedHeight: px(baseExpandedHeight)
    property int expandedHeightWithMedia: px(baseExpandedHeightWithMedia)
    property int expandedRadius: Math.round(px(baseExpandedRadius) * cornerScaleSoft)

    // Animations
    readonly property int animDuration: 360
    readonly property int animDurationFast: 180
    readonly property int animDurationTooltip: 120      // tooltip opacity fade & press scale
    readonly property int animDurationPopover: 160      // popover X/Y repositioning slide
    readonly property int animDurationTopBar: 260       // top-bar mode height morph (tighter, no overshoot)
    readonly property int animDurationProgress: 300     // live progress bar fills
    readonly property int animEasing: Easing.OutBack
    readonly property real animOvershoot: 1.08
    readonly property real animEntranceOvershoot: 1.15  // scale-from-zero entrance (bubbles, pills appearing)

    // Behavior flags
    property bool use24Hour: true
    property bool showSeconds: true
    property bool showBattery: true
    property bool showMediaWhenPlaying: true
    property bool hideOnFullscreen: true
    property bool morphToTopBarWhenMaximized: true
    property bool reserveSpaceWhenMaximized: true
    property int topBarHeight: px(baseTopBarHeight)
    property int autoCollapseTimeout: 6000

    // Dock Styling & Dimensions
    property string dockPosition: "bottom"
    property int baseDockIconSize: 44
    property int dockIconSize: px(baseDockIconSize)
    property real dockScaleHover: 1.28
    property real dockScaleAdjacent: 1.12
    property int dockHeight: Math.round(dockIconSize * Math.max(1.2, dockScaleHover) + px(16))
    property int dockRadius: Math.round(px(Math.min(22, Math.round(dockHeight / 3))) * cornerScaleSoft)
    // Running-indicator dots under the dock icons
    property int dockDotSize: px(4)
    property int dockDotSpacing: px(3)
    // Launcher: gap to the screen edge, height with file results, height of the file pane
    property int launcherEdgeMargin: px(32)
    property int launcherCombinedHeight: px(700)
    property int launcherCombinedHeightCompact: px(640)
    property int launcherFilePaneHeight: px(236)
    property int launcherFilePaneHeightCompact: px(200)
    // Column of System Settings pages beside the apps
    property int launcherSettingsPaneWidth: px(250)
    property int dockBottomMargin: px(baseDockBottomMargin)
    property bool dockReserveSpace: false
    property bool dockAutoHideOnFullscreen: true
    property bool dockAutoHideFromWindows: true
    property bool dockAutoHideAlways: false
    property bool dockShowBorder: false
    // Hue of the dock, the launcher and the dock's popups, chosen by name from
    // dockTintChoices (SettingsService.dockTint). "cool" is the scheme's default
    // tone (slightly blue on dark, warm paper on light, the island's glass in the glass style), "neutral" a plain grey, "accent" follows the accent color, and
    // the rest are fixed hues. `color` is only what the settings swatch shows.
    property string dockTintName: "cool"
    // How much of a chosen hue is mixed into the dark base (0.02 to 0.20). Does not
    // apply to "cool" and "neutral", which have fixed colors.
    property real dockTintStrength: 0.08
    // Opacity of the dock, remembered separately for the solid and the glass look
    property real dockOpacity: 0.85
    property real dockGlassOpacity: 0.35
    readonly property real dockAlpha: glass ? dockGlassOpacity : dockOpacity
    readonly property bool dockTintHasHue: dockTintName !== "cool" && dockTintName !== "neutral"
    readonly property var dockTintChoices: [
        { "name": "cool", "label": "Default", "color": isLight ? (glass ? "#c8c8ce" : "#cfc6b6") : "#5b6078" },
        { "name": "neutral", "label": "Neutral", "color": "#6e6e73" },
        { "name": "accent", "label": "Match accent", "color": accent, "hollow": true },
        { "name": "blue", "label": "Blue", "color": accentBlue },
        { "name": "indigo", "label": "Indigo", "color": accentIndigo },
        { "name": "purple", "label": "Purple", "color": accentPurple },
        { "name": "red", "label": "Red", "color": accentRed },
        { "name": "orange", "label": "Orange", "color": accentOrange },
        { "name": "yellow", "label": "Yellow", "color": accentYellow },
        { "name": "green", "label": "Green", "color": accentGreen },
        { "name": "cyan", "label": "Cyan", "color": accentCyan }
    ]
    // Frosted glass translucent tint when transparent mode is enabled, or deep OLED dark when solid
    readonly property color dockBackground: {
        let alpha = dockAlpha;
        if (isLight) {
            // The same choices on a near-white base, with the hue taken out of
            // white instead of added to black
            if (dockTintName === "neutral") return Qt.rgba(0.95, 0.95, 0.95, alpha);
            let lightHue = null;
            for (let j = 0; j < dockTintChoices.length; j++) {
                if (dockTintChoices[j].name === dockTintName && dockTintHasHue) lightHue = dockTintChoices[j].color;
            }
            // The default is the island's glass
            if (lightHue === null) return glass ? Qt.rgba(glassFill.r, glassFill.g, glassFill.b, alpha) : Qt.rgba(0.965, 0.945, 0.915, alpha);
            let lightMix = dockTintStrength * 1.5;
            return Qt.rgba(0.97 - (1 - lightHue.r) * lightMix, 0.97 - (1 - lightHue.g) * lightMix, 0.97 - (1 - lightHue.b) * lightMix, alpha);
        }
        if (dockTintName === "neutral") {
            let grey = glass ? 0.135 : 0.085;
            return Qt.rgba(grey, grey, grey, alpha);
        }
        let hue = null;
        for (let i = 0; i < dockTintChoices.length; i++) {
            if (dockTintChoices[i].name === dockTintName && dockTintHasHue) hue = dockTintChoices[i].color;
        }
        if (hue === null) {
            return glass ? Qt.rgba(0.12, 0.13, 0.16, alpha) : Qt.rgba(0.08, 0.08, 0.10, alpha);
        }
        // A dark base with a little of the hue mixed in: clearly tinted, still dark
        // enough for white text
        let base = glass ? 0.10 : 0.05;
        let mix = dockTintStrength;
        return Qt.rgba(base + hue.r * mix, base + hue.g * mix, base + hue.b * mix, alpha);
    }
    readonly property color dockBorder: overlay(0.18)
    // Opacity of the dock's popups: well above a see-through dock so their content
    // reads, but less on blurred glass, where the blur does part of that. Follows the
    // dock when the dock is more opaque.
    readonly property real dockPopupAlpha: Math.max(dockAlpha, glass ? glassFillStrong.a : 0.97)
}
