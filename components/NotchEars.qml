import ".."
import QtQuick
import QtQuick.Shapes

// The two soft curves that flare a pill into the top edge of the screen, so a pill
// hugging the top reads as part of it, like the MacBook notch. Put it next to the
// pill's body (not inside, where the body clips it) and point `body` at it.
Item {
    id: root

    property Rectangle body: null
    property bool active: Theme.notchStyle
    property color color: body ? body.color : Theme.islandBackground

    readonly property real size: body ? Math.max(0, Math.min(Theme.notchEar, body.height / 2)) : 0

    x: body ? body.x - size : 0
    y: body ? body.y : 0
    width: body ? body.width + 2 * size : 0
    height: size
    visible: active && size > 0.5 && (body ? body.opacity > 0.01 : false)

    // Curves are mirrored: left one in the first path, right one in the second.
    // Each fills the corner between the screen edge and the pill's side.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine { x: root.size; y: 0 }
            PathLine { x: root.size; y: root.size }
            PathArc { x: 0; y: 0; radiusX: root.size; radiusY: root.size; direction: PathArc.Counterclockwise }
        }

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            startX: root.width
            startY: 0
            PathLine { x: root.width - root.size; y: 0 }
            PathLine { x: root.width - root.size; y: root.size }
            PathArc { x: root.width; y: 0; radiusX: root.size; radiusY: root.size; direction: PathArc.Clockwise }
        }
    }
}
