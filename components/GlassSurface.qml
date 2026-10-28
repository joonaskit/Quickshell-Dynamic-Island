import ".."
import QtQuick
import QtQuick.Shapes

// The light of the glass look (Theme.glass) over a translucent body: a sheen lit from
// above, and a rim that is bright along the top and bottom edges, where thick glass
// bends the most light. Put it inside the body, before its content, and point `body`
// at it. It follows the body's size and corner radii, and hides with a clear body.
Item {
    id: root

    property Rectangle body: null
    property bool active: Theme.glass
    // The body hangs from the top edge with notch ears (NotchEars) beside it. The
    // body then has no border, and this draws the hairline instead, clear where the
    // ears join the sides, so the outline runs on round the ears without a seam.
    property bool flushTop: false
    // With flushTop, how far down the sides the ears are (NotchEars.inset)
    property real flushInset: 0
    // With flushTop, draw the hairline down the sides
    property bool hairline: true

    // Inside the body's own border, which on glass is the dark hairline
    readonly property real inset: body ? body.border.width : 0
    readonly property real rimWidth: 1
    // The softer band inside the rim that gives the edge its thickness
    readonly property real bandWidth: Theme.px(3)
    // Where the hairline and rim start down the sides: below the ears, which are as
    // tall as NotchEars makes them
    readonly property real topClear: flushTop ? flushInset + Math.max(0, Math.min(Theme.notchEar, (height - flushInset) / 2)) : 0
    readonly property real clearStop: height > 0 ? Math.min(0.99, topClear / height) : 0

    anchors.fill: parent
    visible: active && body !== null && body.color.a > 0.01

    function innerRadius(radius, by) {
        return Math.max(0, radius - by);
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.inset
        topLeftRadius: root.body ? root.innerRadius(root.body.topLeftRadius, root.inset) : 0
        topRightRadius: root.body ? root.innerRadius(root.body.topRightRadius, root.inset) : 0
        bottomLeftRadius: root.body ? root.innerRadius(root.body.bottomLeftRadius, root.inset) : 0
        bottomRightRadius: root.body ? root.innerRadius(root.body.bottomRightRadius, root.inset) : 0
        // Flush with the top edge the ears carry on the body's top, so no sheen there
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.flushTop ? "transparent" : Theme.glassSheen }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.glassSheenLow }
        }
    }

    // Rim and band are rings: an outer and an inner rounded rectangle filled even-odd
    Shape {
        id: rings
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        readonly property real tl: root.body ? root.body.topLeftRadius : 0
        readonly property real tr: root.body ? root.body.topRightRadius : 0
        readonly property real bl: root.body ? root.body.bottomLeftRadius : 0
        readonly property real br: root.body ? root.body.bottomRightRadius : 0
        readonly property real hairIn: root.flushTop ? 1 : 0
        readonly property real rimIn: root.inset + hairIn + root.rimWidth
        readonly property real bandIn: rimIn + root.bandWidth

        // The hairline, when the body has no border of its own
        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: root.clearStop; color: "transparent" }
                GradientStop { position: root.clearStop + 0.001; color: root.flushTop && root.hairline ? Theme.glassHairline : "transparent" }
                GradientStop { position: 1.0; color: root.flushTop && root.hairline ? Theme.glassHairline : "transparent" }
            }
            PathRectangle {
                x: 0; y: 0
                width: root.width
                height: root.height
                topLeftRadius: rings.tl
                topRightRadius: rings.tr
                bottomLeftRadius: rings.bl
                bottomRightRadius: rings.br
            }
            PathRectangle {
                x: rings.hairIn; y: rings.hairIn
                width: Math.max(0, root.width - 2 * rings.hairIn)
                height: Math.max(0, root.height - 2 * rings.hairIn)
                topLeftRadius: root.innerRadius(rings.tl, rings.hairIn)
                topRightRadius: root.innerRadius(rings.tr, rings.hairIn)
                bottomLeftRadius: root.innerRadius(rings.bl, rings.hairIn)
                bottomRightRadius: root.innerRadius(rings.br, rings.hairIn)
            }
        }

        // Lit from above; when flush with the top edge there is no top edge to light,
        // so it starts below the ears
        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop { position: 0.0; color: root.flushTop ? "transparent" : Theme.glassRimTop }
                GradientStop { position: root.clearStop; color: root.flushTop ? "transparent" : Theme.glassRimTop }
                GradientStop { position: Math.max(0.5, root.clearStop + 0.01); color: Theme.glassRimSide }
                GradientStop { position: 1.0; color: Theme.glassRimBottom }
            }
            PathRectangle {
                x: root.inset; y: root.inset
                width: Math.max(0, root.width - 2 * root.inset)
                height: Math.max(0, root.height - 2 * root.inset)
                topLeftRadius: root.innerRadius(rings.tl, root.inset)
                topRightRadius: root.innerRadius(rings.tr, root.inset)
                bottomLeftRadius: root.innerRadius(rings.bl, root.inset)
                bottomRightRadius: root.innerRadius(rings.br, root.inset)
            }
            PathRectangle {
                x: rings.rimIn; y: rings.rimIn
                width: Math.max(0, root.width - 2 * rings.rimIn)
                height: Math.max(0, root.height - 2 * rings.rimIn)
                topLeftRadius: root.innerRadius(rings.tl, rings.rimIn)
                topRightRadius: root.innerRadius(rings.tr, rings.rimIn)
                bottomLeftRadius: root.innerRadius(rings.bl, rings.rimIn)
                bottomRightRadius: root.innerRadius(rings.br, rings.rimIn)
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                // Hanging from a bar (flushInset), the top is the bar's, which draws its own
                GradientStop { position: 0.0; color: root.flushTop && root.flushInset > 0 ? "transparent" : Theme.glassBandTop }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.glassBandBottom }
            }
            PathRectangle {
                x: rings.rimIn; y: rings.rimIn
                width: Math.max(0, root.width - 2 * rings.rimIn)
                height: Math.max(0, root.height - 2 * rings.rimIn)
                topLeftRadius: root.innerRadius(rings.tl, rings.rimIn)
                topRightRadius: root.innerRadius(rings.tr, rings.rimIn)
                bottomLeftRadius: root.innerRadius(rings.bl, rings.rimIn)
                bottomRightRadius: root.innerRadius(rings.br, rings.rimIn)
            }
            PathRectangle {
                x: rings.bandIn; y: rings.bandIn
                width: Math.max(0, root.width - 2 * rings.bandIn)
                height: Math.max(0, root.height - 2 * rings.bandIn)
                topLeftRadius: root.innerRadius(rings.tl, rings.bandIn)
                topRightRadius: root.innerRadius(rings.tr, rings.bandIn)
                bottomLeftRadius: root.innerRadius(rings.bl, rings.bandIn)
                bottomRightRadius: root.innerRadius(rings.br, rings.bandIn)
            }
        }
    }
}
