import ".."
import QtQuick
import QtQuick.Shapes

// A soft glow along the edge of the pill that covers a tucked tab: down its side and
// round its bottom corner, so the tab reads as something waiting underneath. It is
// clipped to the tab and drawn below the covering pill, so only the half of the glow
// outside that pill shows. Purely visual.
Item {
    id: root

    // The tab's body and the covering pill's body, both in the parent's coordinates
    property Item tab: null
    property Item front: null
    property real tabX: 0
    property real tabY: 0
    property real frontX: 0
    property real frontY: 0
    // The covering pill's bottom corner radius
    property real frontRadius: Theme.notchRadius
    // The tab is to the right of the covering pill (its right edge is the seam)
    property bool toRight: false
    property bool active: false
    property color accentColor: Theme.accent

    x: tabX
    y: tabY
    width: tab ? tab.width : 0
    height: tab ? tab.height : 0
    clip: true
    enabled: false

    opacity: active ? 1.0 : 0.0
    visible: opacity > 0.005 && tab !== null && front !== null

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
    }

    // Gentle breathing while the tab is tucked
    property real pulse: 1.0
    SequentialAnimation on pulse {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
    }

    // The seam in local coordinates: the covering pill's edge and its bottom corner
    readonly property real seamX: front ? (toRight ? frontX + front.width : frontX) - x : 0
    readonly property real seamTop: front ? frontY - y : 0
    readonly property real seamBottom: front ? frontY + front.height - y : 0
    readonly property real r: Math.max(0, Math.min(frontRadius, (seamBottom - seamTop) / 2))
    // Off the end of the curve, towards the inside of the covering pill
    readonly property real endX: toRight ? seamX - r : seamX + r

    // Stacked strokes, wide and faint to thin and bright, read as a glow
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.pulse

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.1)
            strokeWidth: Theme.px(12)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.seamX
            startY: root.seamTop - Theme.px(12)
            PathLine { x: root.seamX; y: root.seamBottom - root.r }
            PathArc { x: root.endX; y: root.seamBottom; radiusX: root.r; radiusY: root.r; direction: root.toRight ? PathArc.Clockwise : PathArc.Counterclockwise }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
            strokeWidth: Theme.px(7)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.seamX
            startY: root.seamTop - Theme.px(7)
            PathLine { x: root.seamX; y: root.seamBottom - root.r }
            PathArc { x: root.endX; y: root.seamBottom; radiusX: root.r; radiusY: root.r; direction: root.toRight ? PathArc.Clockwise : PathArc.Counterclockwise }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)
            strokeWidth: Theme.px(3)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.seamX
            startY: root.seamTop - Theme.px(3)
            PathLine { x: root.seamX; y: root.seamBottom - root.r }
            PathArc { x: root.endX; y: root.seamBottom; radiusX: root.r; radiusY: root.r; direction: root.toRight ? PathArc.Clockwise : PathArc.Counterclockwise }
        }
    }
}
