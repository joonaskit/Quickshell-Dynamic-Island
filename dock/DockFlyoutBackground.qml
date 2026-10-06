import ".."
import QtQuick
import QtQuick.Shapes

// Dock-textured body for a popup attached to the dock. Fills its parent, with
// concave fillets flaring onto the dock so the two read as one shape. Drawn for
// a bottom dock (base at the bottom edge) and rotated for left / right docks.
Item {
    id: bgHolder

    property bool isVertical: false
    property string dockPosition: "bottom"
    // Fillets are dropped when the popup overhangs the dock's straight edge
    property bool fitsOnDock: true
    property real filletSize: 12
    property real cornerRadius: 14
    // Opacity of the body; it fades to the exact dock colour at the base
    property real tintAlpha: Theme.dockTransparent ? 0.9 : 0.97
    readonly property color tintColor: Qt.rgba(Theme.dockBackground.r, Theme.dockBackground.g, Theme.dockBackground.b, tintAlpha)

    anchors.centerIn: parent
    width: isVertical ? parent.height : parent.width
    height: isVertical ? parent.width : parent.height
    rotation: !isVertical ? 0 : (dockPosition === "left" ? 90 : -90)

    readonly property real w: width
    readonly property real h: height
    // Shrink the curves while the body is still too small to hold them
    readonly property real r: Math.max(0, Math.min(cornerRadius, h / 2, w / 2))
    readonly property real f: fitsOnDock ? Math.max(0, Math.min(filletSize, h - r)) : 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // More opaque than the dock for readability, fading to the exact dock
            // colour at the base so the join stays seamless
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: bgHolder.h
                GradientStop { position: 0.0; color: bgHolder.tintColor }
                GradientStop { position: Math.max(0.0, 1.0 - (bgHolder.filletSize * 2.5) / Math.max(1, bgHolder.h)); color: bgHolder.tintColor }
                GradientStop { position: 1.0; color: Theme.dockBackground }
            }
            strokeColor: Theme.dockShowBorder ? Theme.dockBorder : "transparent"
            strokeWidth: 1

            // Left fillet, flaring out onto the dock
            startX: -bgHolder.f
            startY: bgHolder.h
            PathArc {
                x: 0; y: bgHolder.h - bgHolder.f
                radiusX: bgHolder.f; radiusY: bgHolder.f
                direction: PathArc.Counterclockwise
            }
            // Left side and top-left corner
            PathLine { x: 0; y: bgHolder.r }
            PathArc {
                x: bgHolder.r; y: 0
                radiusX: bgHolder.r; radiusY: bgHolder.r
            }
            // Top edge and top-right corner
            PathLine { x: bgHolder.w - bgHolder.r; y: 0 }
            PathArc {
                x: bgHolder.w; y: bgHolder.r
                radiusX: bgHolder.r; radiusY: bgHolder.r
            }
            // Right side and right fillet
            PathLine { x: bgHolder.w; y: bgHolder.h - bgHolder.f }
            PathArc {
                x: bgHolder.w + bgHolder.f; y: bgHolder.h
                radiusX: bgHolder.f; radiusY: bgHolder.f
                direction: PathArc.Counterclockwise
            }
            // Base, lying on the dock edge
            PathLine { x: -bgHolder.f; y: bgHolder.h }
        }
    }
}
