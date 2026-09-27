pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // Apple OLED true black and sleek translucent border
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

    // Text colors (iOS standard label hierarchy)
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#98989d"
    readonly property color textTertiary: "#636366"

    // Apple accent colors
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
    readonly property string fontFamily: "SF Pro Text, Cantarell, Noto Sans, Liberation Sans, -apple-system, sans-serif"
    readonly property string fontDisplay: "SF Pro Display, Cantarell, Noto Sans, Liberation Sans, -apple-system, sans-serif"

    // Dimensions
    property int topMargin: 10
    property int compactWidthClock: 154
    property int compactWidthMedia: 228
    property int compactHeight: 38
    property int compactRadius: 19

    property int expandedWidth: 410
    property int expandedHeight: 180
    property int expandedHeightWithMedia: 236
    property int expandedRadius: 28

    // Animations
    readonly property int animDuration: 360
    readonly property int animDurationFast: 180
    readonly property int animEasing: Easing.OutBack
    readonly property real animOvershoot: 1.08

    // Behavior flags
    property bool use24Hour: true
    property bool showSeconds: true
    property bool showBattery: true
    property bool showMediaWhenPlaying: true
    property bool hideOnFullscreen: true
    property bool morphToTopBarWhenMaximized: true
    property bool reserveSpaceWhenMaximized: true
    property int topBarHeight: 34
    property bool allScreens: false
    property int autoCollapseTimeout: 6000

    // Dock Styling & Dimensions
    property int dockHeight: 64
    property int dockIconSize: 44
    property int dockRadius: 20
    property int dockBottomMargin: 12
    property real dockScaleHover: 1.28
    property real dockScaleAdjacent: 1.12
    property bool dockReserveSpace: false
    property bool dockAutoHideOnFullscreen: true
    readonly property color dockBackground: Qt.rgba(0.08, 0.08, 0.10, 0.85)
    readonly property color dockBorder: Qt.rgba(1, 1, 1, 0.14)
    readonly property color dockShadow: Qt.rgba(0, 0, 0, 0.40)
}
