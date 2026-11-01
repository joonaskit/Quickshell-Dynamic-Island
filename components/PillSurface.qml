import ".."
import QtQuick

// What a top pill draws over its body on glass: the light of the glass, and the separate
// card a detached BarHang opens instead. Put it in the body, before its content.
Item {
    id: surface

    property BarHang hang: null
    property NotchEars ears: null
    // The menu's card, for the window's blur while detached (BarHang.bubble)
    readonly property alias card: bubbleCard

    anchors.fill: parent

    BarBubble {
        id: bubbleCard
        hang: surface.hang
    }

    GlassSurface {
        body: surface.hang ? surface.hang.body : null
        flushTop: surface.ears ? surface.ears.active : false
        flatTop: Theme.notchStyle && !(surface.hang && surface.hang.topBarMode)
        flushInset: surface.ears ? surface.ears.inset : 0
        hairline: !(surface.hang && surface.hang.joined)
        active: Theme.glass && !(surface.hang && surface.hang.bubble)
    }
}
