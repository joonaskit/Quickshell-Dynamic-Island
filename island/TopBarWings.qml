import ".."
import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower

Item {
    id: root

    property bool isMaximized: false
    property string activeAppTitle: ""
    property date currentDate: new Date()
    property var displayBattery: UPower.displayDevice
    property real compactCenterWidth: Theme.compactWidthClock
    // The bar's body, for the window's blur
    property alias bar: barBackground
    // The bodies hanging from the bar (BarHang.gap: { x, width } in the window, which this
    // fills). The bar leaves out its lower edge under each, so they carry on from the bar
    // without a line across.
    property var gaps: []
    // The lower edge that is kept: the bar's width less the gaps, as { x, width }
    readonly property var edgeSegments: {
        let holes = gaps.map(g => ({ x: g.x - barBackground.x, width: g.width })).sort((a, b) => a.x - b.x);
        let segments = [];
        let from = 0;
        for (let hole of holes) {
            if (hole.x > from) segments.push({ x: from, width: hole.x - from });
            from = Math.max(from, hole.x + hole.width);
        }
        if (from < barBackground.width) segments.push({ x: from, width: barBackground.width - from });
        return segments;
    }
    // How tall that lower edge is: the glass rim and the band inside it, with room for
    // their antialiasing. Its top is on a whole device pixel, where the island's fill
    // starts too, so no pixel is half covered by both and shows as a seam.
    readonly property real edgeDepth: {
        let dpr = Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1;
        let bottom = Theme.topBarHeight + 1;
        let top = Math.floor((bottom - barGlass.rimWidth - barGlass.bandWidth - Theme.px(2)) * dpr) / dpr;
        return bottom - top;
    }

    Behavior on compactCenterWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutCubic
        }
    }

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Theme.topMargin + Theme.compactHeight + Theme.px(6)

    // Set while the bar retracts into the island after the window is unmaximized
    property bool retracting: false
    onIsMaximizedChanged: retracting = !isMaximized

    // Bar visibility: visible when maximized or while fluidly growing/retracting. Not
    // when the island itself changes width: the bar follows it a little behind, and
    // showing that drew a second, wider body behind the pill, which shows through glass.
    visible: root.isMaximized || (root.retracting && barBackground.width > (root.compactCenterWidth + 2))

    // Full-width continuous top bar background that grows fluidly from the center Island
    Rectangle {
        id: barBackground
        anchors.horizontalCenter: parent.horizontalCenter

        // Horizontal growth: expands from compact pill width to full screen width
        width: root.isMaximized ? root.width : root.compactCenterWidth

        // Vertical glide: moves smoothly from topMargin (10px) to top edge (0px)
        y: root.isMaximized ? 0 : (Theme.notchStyle ? -1 : Theme.topMargin)

        // Height adjusts from compact pill height (38px) to top bar height (35px)
        height: root.isMaximized ? (Theme.topBarHeight + 1) : Theme.compactHeight

        // Radii: morphs from pill radius (19px) to flat (0px) as wings meet the display bezels
        topLeftRadius: (root.isMaximized || Theme.notchStyle) ? 0 : Theme.compactRadius
        topRightRadius: (root.isMaximized || Theme.notchStyle) ? 0 : Theme.compactRadius
        bottomLeftRadius: root.isMaximized ? 0 : (Theme.notchStyle ? Theme.notchRadius : Theme.compactRadius)
        bottomRightRadius: root.isMaximized ? 0 : (Theme.notchStyle ? Theme.notchRadius : Theme.compactRadius)

        color: Theme.islandSurface
        clip: true

        layer.enabled: root.gaps.length > 0
        // Kept where the mask is opaque. The default thresholds leave smoothstep with equal
        // edges, which is undefined, and a spread from 0 keeps alpha 0 too: so a ramp round
        // 0.5, and the upper cut above 1
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: gapMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
            maskThresholdMax: 1.0
            maskSpreadAtMax: 0.5
        }

        onWidthChanged: {
            if (root.retracting && width <= root.compactCenterWidth + 2) root.retracting = false;
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on topLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on topRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        GlassSurface {
            id: barGlass
            body: barBackground
        }

        // Ultra-sleek hairline border separating top bar from maximized application
        Rectangle {
            id: bottomHairline
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.overlay(0.12)
            opacity: (root.isMaximized && barBackground.width > root.width * 0.85) ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
        }
    }

    // What of the bar to keep: all of it but the lower edge under the gaps
    Item {
        id: gapMask
        x: barBackground.x
        y: barBackground.y
        width: barBackground.width
        height: barBackground.height
        visible: false
        layer.enabled: root.gaps.length > 0

        Rectangle {
            width: parent.width
            height: Math.max(0, parent.height - root.edgeDepth)
            color: "white"
        }

        Repeater {
            model: root.edgeSegments

            Rectangle {
                required property var modelData
                x: modelData.x
                y: Math.max(0, gapMask.height - root.edgeDepth)
                width: modelData.width
                height: Math.min(gapMask.height, root.edgeDepth)
                color: "white"
            }
        }
    }
}
