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

    // Accent colors
    readonly property color accentGreen: "#30d158"
    readonly property color accentBlue: "#0a84ff"
    readonly property color accentOrange: "#ff9f0a"
    readonly property color accentYellow: "#ffd60a"
    readonly property color accentRed: "#ff453a"
    readonly property color accentPurple: "#bf5af2"
    readonly property color accentCyan: "#64d2ff"
    readonly property color accentIndigo: "#5e5ce6"

    // Slider styling
    readonly property color sliderTrack: "#3a3a3c"
    readonly property color sliderFill: "#ffffff"
    readonly property color sliderHandle: "#ffffff"

    // Fonts
    readonly property string fontFamily: "Cantarell, Noto Sans, Liberation Sans, sans-serif"
    readonly property string fontDisplay: "Cantarell, Noto Sans, Liberation Sans, sans-serif"

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
    readonly property int baseDockIconSize: 44
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
    property int dockHeight: px(baseDockHeight)
    property int dockIconSize: px(baseDockIconSize)
    property int dockRadius: px(baseDockRadius)
    property int dockBottomMargin: px(baseDockBottomMargin)
    property real dockScaleHover: 1.28
    property real dockScaleAdjacent: 1.12
    property bool dockReserveSpace: false
    property bool dockAutoHideOnFullscreen: true
    readonly property color dockBackground: Qt.rgba(0.08, 0.08, 0.10, 0.85)
    readonly property color dockBorder: Qt.rgba(1, 1, 1, 0.14)
    readonly property color dockShadow: Qt.rgba(0, 0, 0, 0.40)
}
