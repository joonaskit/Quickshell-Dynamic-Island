import ".."
import QtQuick

// The separate card a detached BarHang draws its menu on, below the bar. Put it in the
// body, before its content.
Rectangle {
    id: bubble

    property BarHang hang: null
    readonly property Rectangle body: hang ? hang.body : null

    visible: hang !== null && hang.bubble && height > 1
    x: 0
    y: hang ? hang.bubbleTop : 0
    width: parent ? parent.width : 0
    height: parent ? Math.max(0, parent.height - y) : 0
    radius: Math.min(Theme.expandedRadius, height / 2)
    color: hang ? hang.bodyColor : "transparent"
    border.width: 1
    border.color: Theme.islandBorder

    GlassSurface {
        body: bubble
    }
}
