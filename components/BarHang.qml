import ".."
import QtQuick

// Lets a top pill's body grow out of the full-width top bar while it is open, as one strip
// with the bar (docs/TOP_BAR.md). Put it in the pill, point `body` at the body and set
// `body.gradient: fill`; the ears, GlassSurface and the window's blur read `joined`.
// Detached (a test, on glass), the body is clear instead and a BarBubble below the bar,
// a gap away from it, draws the menu as a separate card.
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
    // A separate card below the bar instead of one strip with it
    property bool detached: Theme.detachedMenus
    // Between the bar and the card
    readonly property real bubbleGap: Theme.detachedMenuGap

    // Open over the bar, or still shrinking back into it, so the bar's edge does not
    // return while the body closes
    readonly property bool hangs: topBarMode && body !== null && (open || (closing && body.height > barDepth + 1))
    property bool closing: false
    onOpenChanged: closing = !open && topBarMode
    // One strip with the bar, or a card below it (BarBubble)
    readonly property bool joined: hangs && !detached
    readonly property bool bubble: hangs && detached
    // While open as a card: the pill moves its menu down below the card's top, and adds
    // that much to its height
    readonly property bool bubbleOpen: topBarMode && detached && open
    // Where the card starts, measured from the top of the body
    readonly property real bubbleTop: barDepth + bubbleGap

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
    readonly property var gap: joined && pill ? ({ x: pill.x + body.x, width: body.width }) : null

    // Always the body's gradient, and its plain colour when not hanging: a gradient set
    // back to null leaves its last fill drawn, as a block over the bar
    property Gradient fill: Gradient {
        GradientStop { position: 0.0; color: hang.hangs ? "transparent" : hang.bodyColor }
        GradientStop { position: hang.stop(hang.fillTop); color: hang.hangs ? "transparent" : hang.bodyColor }
        GradientStop { position: hang.stop(hang.fillTop + 0.01); color: hang.joined ? hang.barFill : hang.lowerColor }
        GradientStop { position: hang.stop(hang.barDepth + hang.barFade); color: hang.lowerColor }
        GradientStop { position: 1.0; color: hang.lowerColor }
    }
    readonly property color bodyColor: body ? body.color : "transparent"
    // Below the bar: clear as a card, which BarBubble draws instead
    readonly property color lowerColor: bubble ? "transparent" : bodyColor

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
