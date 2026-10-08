pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // OLED true black and sleek translucent border
    readonly property color islandBackground: "#000000"
    readonly property color islandBorder: Qt.rgba(1, 1, 1, 0)
    readonly property color islandBorderHover: Qt.rgba(1, 1, 1, 0)
    readonly property color islandShadow: Qt.rgba(0, 0, 0, 0)

    // Inner card backgrounds & subtle highlights
    readonly property color cardBackground: "#1c1c1e"
    readonly property color cardBackgroundHover: "#2c2c2e"
    readonly property color controlBackground: Qt.rgba(1, 1, 1, 0)
    readonly property color controlBackgroundHover: Qt.rgba(1, 1, 1, 0)
    readonly property color controlBackgroundActive: Qt.rgba(1, 1, 1, 0)

    // Text colors (standard label hierarchy)
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#98989d"
    readonly property color textTertiary: "#636366"
    // Foreground on light fills, and on red fills such as unread badges
    readonly property color lightForeground: "#000000"
    readonly property color dangerForeground: "#ffffff"

    // Accent colors
    readonly property color accentGreen: "#30d158"
    readonly property color accentBlue: "#0a84ff"
    readonly property color accentOrange: "#ff9f0a"
    readonly property color accentYellow: "#ffd60a"
    readonly property color accentRed: "#ff453a"
    readonly property color accentPurple: "#bf5af2"
    readonly property color accentCyan: "#64d2ff"
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

    // The accent at a given opacity, for selection fills and focus borders
    function accentTint(alpha) {
        return Qt.rgba(accent.r, accent.g, accent.b, alpha);
    }

    // Slider styling
    readonly property color sliderTrack: "#3a3a3c"
    readonly property color sliderFill: "#ffffff"
    readonly property color sliderHandle: "#ffffff"
    readonly property color switchTrackOff: "#39393d"

    // Fonts
    readonly property string fontFamily: "Cantarell, Noto Sans, Liberation Sans, sans-serif"
    readonly property string fontDisplay: "Cantarell, Noto Sans, Liberation Sans, sans-serif"

    // Corner radius scale (unscaled), exported to companion apps
    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 14

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
    property int expandedRadius: px(baseExpandedRadius)

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
    property bool allScreens: false
    property int autoCollapseTimeout: 6000

    // Dock Styling & Dimensions
    property string dockPosition: "bottom"
    property int baseDockIconSize: 44
    property int dockIconSize: px(baseDockIconSize)
    property real dockScaleHover: 1.28
    property real dockScaleAdjacent: 1.12
    property int dockHeight: Math.round(dockIconSize * Math.max(1.2, dockScaleHover) + px(16))
    property int dockRadius: px(Math.min(22, Math.round(dockHeight / 3)))
    property int dockBottomMargin: px(baseDockBottomMargin)
    property bool dockReserveSpace: false
    property bool dockAutoHideOnFullscreen: true
    property bool dockAutoHideFromWindows: true
    property bool dockAutoHideAlways: false
    property bool dockShowBorder: false
    property bool dockTransparent: false
    // Hue of the dock, the launcher and the dock's popups, chosen by name from
    // dockTintChoices (SettingsService.dockTint). "cool" is the original slightly
    // blue tone, "neutral" a plain grey, "accent" follows the accent color, and
    // the rest are fixed hues. `color` is only what the settings swatch shows.
    property string dockTintName: "cool"
    // How much of a chosen hue is mixed into the dark base (0.02 to 0.20). Does not
    // apply to "cool" and "neutral", which have fixed colors.
    property real dockTintStrength: 0.08
    // Opacity of the dock, remembered separately for the solid and the glass look
    property real dockOpacity: 0.85
    property real dockGlassOpacity: 0.35
    readonly property real dockAlpha: dockTransparent ? dockGlassOpacity : dockOpacity
    readonly property bool dockTintHasHue: dockTintName !== "cool" && dockTintName !== "neutral"
    readonly property var dockTintChoices: [
        { "name": "cool", "label": "Cool (default)", "color": "#5b6078" },
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
        if (dockTintName === "neutral") {
            let grey = dockTransparent ? 0.135 : 0.085;
            return Qt.rgba(grey, grey, grey, alpha);
        }
        let hue = null;
        for (let i = 0; i < dockTintChoices.length; i++) {
            if (dockTintChoices[i].name === dockTintName && dockTintHasHue) hue = dockTintChoices[i].color;
        }
        if (hue === null) {
            return dockTransparent ? Qt.rgba(0.12, 0.13, 0.16, alpha) : Qt.rgba(0.08, 0.08, 0.10, alpha);
        }
        // A dark base with a little of the hue mixed in: clearly tinted, still dark
        // enough for white text
        let base = dockTransparent ? 0.10 : 0.05;
        let mix = dockTintStrength;
        return Qt.rgba(base + hue.r * mix, base + hue.g * mix, base + hue.b * mix, alpha);
    }
    readonly property color dockBorder: Qt.rgba(1, 1, 1, 0.18)
}
