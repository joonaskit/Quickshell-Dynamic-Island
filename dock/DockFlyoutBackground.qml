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
    // One side continues an end of the dock in a straight line, filling in the
    // dock's rounded corner below it. Start is left, or top for a vertical dock.
    property bool startFlush: false
    property bool endFlush: false
    readonly property bool flush: startFlush || endFlush
    // Fillet on the far side (the one away from that end), and how far that side
    // reaches past the other end of the dock. Past the end it has nothing to
    // join, so its base corner is rounded.
    property real farFillet: fitsOnDock ? filletSize : 0
    property real farOverhang: 0
    // Opacity of the body; it fades to the exact dock colour at the base
    property real tintAlpha: Theme.dockTransparent ? 0.9 : 0.97
    readonly property color tintColor: Qt.rgba(Theme.dockBackground.r, Theme.dockBackground.g, Theme.dockBackground.b, tintAlpha)

    anchors.centerIn: parent
    width: isVertical ? parent.height : parent.width
    height: isVertical ? parent.width : parent.height
    rotation: !isVertical ? 0 : (dockPosition === "left" ? 90 : -90)
    // The outline is drawn with the flush side on its left. It is mirrored for a
    // right dock, where rotation alone puts the start (top) side on the right,
    // and when the flush side is the end.
    transform: Scale {
        origin.x: bgHolder.width / 2
        xScale: ((bgHolder.dockPosition === "right") !== bgHolder.endFlush) ? -1 : 1
    }

    readonly property real w: width
    readonly property real h: height
    // Shrink the curves while the body is still too small to hold them
    readonly property real r: Math.max(0, Math.min(cornerRadius, h / 2, w / 2))
    readonly property real nearF: flush ? 0 : Math.max(0, Math.min(fitsOnDock ? filletSize : 0, h - r))
    readonly property real farF: Math.max(0, Math.min(farFillet, h - r))
    readonly property real farR: Math.max(0, Math.min(farOverhang, r))
    readonly property real dockR: flush ? Theme.dockRadius : 0

    // Outline, clockwise from the near (left) side's base. Arcs: "A rx ry 0 0 sweep x y",
    // sweep 1 = clockwise (convex corners), 0 = counterclockwise (concave joins).
    readonly property string outline: {
        let n = v => v.toFixed(2);
        let arc = (radius, sweep, x, y) => radius > 0.01 ? ` A ${n(radius)} ${n(radius)} 0 0 ${sweep} ${n(x)} ${n(y)}` : ` L ${n(x)} ${n(y)}`;
        let p;
        if (flush) {
            // Straight down past the base, to where the dock's corner meets its side
            p = `M 0 ${n(h + dockR)}`;
        } else {
            p = `M ${n(-nearF)} ${n(h)}` + arc(nearF, 0, 0, h - nearF);
        }
        // Near side, top corners
        p += ` L 0 ${n(r)}` + arc(r, 1, r, 0);
        p += ` L ${n(w - r)} 0` + arc(r, 1, w, r);
        // Far side: rounded off when it overhangs the dock, else a fillet onto it
        if (farR > 0.01) {
            p += ` L ${n(w)} ${n(h - farR)}` + arc(farR, 1, w - farR, h);
        } else {
            p += ` L ${n(w)} ${n(h - farF)}` + arc(farF, 0, w + farF, h);
        }
        // Base, lying on the dock edge
        if (flush) {
            // Follow the dock's rounded corner back down to the start point
            p += ` L ${n(dockR)} ${n(h)}` + arc(dockR, 0, 0, h + dockR);
        } else {
            p += ` L ${n(-nearF)} ${n(h)}`;
        }
        return p + " Z";
    }

    // Absorbs hover over the whole popup. The dock's magnification tracker reaches
    // a little above the dock, under the popup's base; without this, hover falls
    // through the gaps between the popup's own items and the dock icons twitch.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

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

            startX: 0
            startY: 0
            PathSvg { path: bgHolder.outline }
        }
    }
}
