import ".."
import QtQuick

// Lets a top pill's body grow out of the full-width top bar while it is open, as one strip
// with the bar (docs/TOP_BAR.md). Put it in the pill, point `body` at the body and set
// `body.gradient: fill`; the ears, GlassSurface and the window's blur read `hangs`.
Item {
    id: hang
    visible: false

    property Rectangle body: null
    // The pill, which places the body in the window, for `gap`
    property Item pill: null
    property bool topBarMode: false
    property bool open: false
    // How tall the bar's lower edge is (TopBarWings.edgeDepth)
    property real barEdge: 0

    // Open over the bar, or still shrinking back into it, so the bar's edge does not
    // return while the body closes
    readonly property bool hangs: topBarMode && body !== null && (open || (closing && body.height > barDepth + 1))
    property bool closing: false
    onOpenChanged: closing = !open && topBarMode

    Connections {
        target: hang.body
        function onHeightChanged() {
            if (hang.closing && hang.body.height <= hang.barDepth + 1) hang.closing = false;
        }
    }

    // The bar's lower edge, measured from the top of the body
    readonly property real barDepth: body ? Theme.topBarHeight + 1 - body.y : 0
    // Below the bar, the fill starts as the bar's and deepens to the body's own over this
    readonly property real barFade: Theme.px(28)
    // Where the fill starts: a device pixel above the cut, which the bar's mask leaves a
    // pixel short of, so they overlap instead of leaving a light line
    readonly property real fillTop: barDepth - barEdge - 1 / (Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1)
    // The bar's fill at its lower edge: on glass, with the faint sheen GlassSurface puts there
    readonly property color barFill: Theme.glass ? over(Theme.glassSheenLow, Theme.islandSurface) : Theme.islandSurface
    // Where the body is in the window, for TopBarWings.gaps (null while not hanging)
    readonly property var gap: hangs && pill ? ({ x: pill.x + body.x, width: body.width }) : null

    // Always the body's gradient, and its plain colour when not hanging: a gradient set
    // back to null leaves its last fill drawn, as a block over the bar
    property Gradient fill: Gradient {
        GradientStop { position: 0.0; color: hang.hangs ? "transparent" : hang.bodyColor }
        GradientStop { position: hang.stop(hang.fillTop); color: hang.hangs ? "transparent" : hang.bodyColor }
        GradientStop { position: hang.stop(hang.fillTop + 0.01); color: hang.hangs ? hang.barFill : hang.bodyColor }
        GradientStop { position: hang.stop(hang.barDepth + hang.barFade); color: hang.bodyColor }
        GradientStop { position: 1.0; color: hang.bodyColor }
    }
    readonly property color bodyColor: body ? body.color : "transparent"

    function stop(depth) {
        return body && body.height > 0 ? Math.max(0, Math.min(1, depth / body.height)) : 0;
    }

    // `top` drawn over `bottom`, both translucent
    function over(top, bottom) {
        let a = top.a + bottom.a * (1 - top.a);
        if (a <= 0) return Qt.rgba(0, 0, 0, 0);
        let mix = (t, b) => (t * top.a + b * bottom.a * (1 - top.a)) / a;
        return Qt.rgba(mix(top.r, bottom.r), mix(top.g, bottom.g), mix(top.b, bottom.b), a);
    }
}
