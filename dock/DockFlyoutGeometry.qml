import ".."
import QtQuick

// Geometry for a popup that grows out of the dock: its base stays flush on the
// dock edge and it spreads from the origin point (e.g. the clicked icon) to its
// final size. Bind the popup's x / y / width / height to the outputs.
//
// While the popup is open, a new origin or size is morphed to rather than
// jumped to, so one popup can be retargeted from icon to icon.
QtObject {
    id: geo

    // Inputs
    property bool open: false
    property bool isVertical: false
    property string dockPosition: "bottom"
    property real dockCapsuleX: 0
    property real dockCapsuleY: 0
    property real dockCapsuleWidth: 0
    property real dockCapsuleHeight: 0
    // Point on the dock the popup grows from
    property real targetX: 0
    property real targetY: 0
    property real finalWidth: 0
    property real finalHeight: 0
    property real parentWidth: 0
    property real parentHeight: 0
    property real filletSize: 12
    property real originSize: Theme.dockIconSize
    // "center": centred on the origin point, kept on the dock's straight edge.
    // "start" / "end": one side in line with that end of the dock (start is left,
    // or top for a vertical dock), growing from that corner. The origin point is
    // not used.
    property string align: "center"

    // Morph progress: 0 = flush with the dock at the origin, 1 = fully open
    property real progress: open ? 1.0 : 0.0
    Behavior on progress {
        NumberAnimation {
            duration: geo.open ? Theme.animDuration : Theme.animDurationFast
            easing.type: geo.open ? Theme.animEasing : Easing.OutCubic
            easing.overshoot: Theme.animOvershoot
        }
    }

    // True once the popup is on screen. From then on, changes to the origin and
    // the final size are animated.
    readonly property bool shown: progress > 0.001

    // Origin along the dock, and the final size along and away from it
    property real origin: isVertical ? targetY : targetX
    property real alongLength: isVertical ? finalHeight : finalWidth
    property real awayLength: isVertical ? finalWidth : finalHeight

    Behavior on origin {
        enabled: geo.shown
        NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic }
    }
    Behavior on alongLength {
        enabled: geo.shown
        NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic }
    }
    Behavior on awayLength {
        enabled: geo.shown
        NumberAnimation { duration: Theme.animDurationTopBar; easing.type: Easing.OutCubic }
    }

    // Content is hidden when the popup is retargeted and fades back in, so the
    // old content is not seen reflowing while the body moves
    property real swapFade: 1.0
    property SequentialAnimation swapAnim: SequentialAnimation {
        PropertyAction { target: geo; property: "swapFade"; value: 0.0 }
        PauseAnimation { duration: 70 }
        NumberAnimation { target: geo; property: "swapFade"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
    }
    onTargetXChanged: if (shown) swapAnim.restart()
    onTargetYChanged: if (shown) swapAnim.restart()

    // Dock edge the popup grows from
    readonly property real dockTop: dockCapsuleY > 0 ? dockCapsuleY : (parentHeight - Theme.dockHeight)
    readonly property real dockSideEdge: dockPosition === "left" ? (dockCapsuleX + dockCapsuleWidth) : dockCapsuleX

    // Extent of the dock's straight edge (inside its rounded corners), along the dock
    readonly property real edgeStart: (isVertical ? dockCapsuleY : dockCapsuleX) + Theme.dockRadius + filletSize
    readonly property real edgeEnd: (isVertical ? (dockCapsuleY + dockCapsuleHeight) : (dockCapsuleX + dockCapsuleWidth)) - Theme.dockRadius - filletSize
    readonly property real capStart: isVertical ? dockCapsuleY : dockCapsuleX
    readonly property real capEnd: capStart + (isVertical ? dockCapsuleHeight : dockCapsuleWidth)
    // False when the dock is too short to carry the whole popup on its straight edge
    readonly property bool fitsOnDock: (edgeEnd - edgeStart) >= alongLength

    // Final position along the dock: centred on the origin, kept on the straight edge
    readonly property real finalAlong: {
        if (startFlush) return capStart;
        if (endFlush) return capEnd - alongLength;
        let pos;
        if (fitsOnDock) {
            pos = Math.max(edgeStart, Math.min(edgeEnd - alongLength, origin - alongLength / 2));
        } else {
            pos = capStart + (capEnd - capStart - alongLength) / 2;
        }
        let limit = (isVertical ? parentHeight : parentWidth) - alongLength - 8;
        return Math.max(8, Math.min(limit, pos));
    }

    readonly property real originAlong: startFlush ? capStart : (endFlush ? (capEnd - originSize) : (origin - originSize / 2))
    readonly property real currentAlong: originAlong + (finalAlong - originAlong) * progress
    readonly property real currentAlongLength: originSize + (alongLength - originSize) * progress
    // Distance grown away from the dock
    readonly property real currentAway: awayLength * progress

    // Outputs
    readonly property real x: isVertical ? (dockPosition === "left" ? dockSideEdge : (dockSideEdge - currentAway)) : currentAlong
    readonly property real y: isVertical ? currentAlong : (dockTop - currentAway)
    readonly property real width: isVertical ? currentAway : currentAlongLength
    readonly property real height: isVertical ? currentAlongLength : currentAway

    // Where full-size content sits inside the growing body: centred along the dock
    // (or pinned to the start side when aligned there) and pinned to the leading
    // edge, so it rides out with the popup
    readonly property real contentX: isVertical ? (dockPosition === "left" ? (width - finalWidth) : 0) : (startFlush ? 0 : (width - finalWidth) / (endFlush ? 1 : 2))
    readonly property real contentY: isVertical ? (startFlush ? 0 : (height - finalHeight) / (endFlush ? 1 : 2)) : 0
    readonly property real contentOpacity: Math.max(0, Math.min(1, (progress - 0.4) / 0.6)) * swapFade

    // Outputs for DockFlyoutBackground when aligned to an end of the dock. The
    // "far" side is the one away from that end.
    readonly property bool startFlush: align === "start"
    readonly property bool endFlush: align === "end"
    readonly property real currentEnd: currentAlong + currentAlongLength
    // Room between the far side and the dock's rounded corner at the other end;
    // negative once the far side has passed it
    readonly property real farRoom: startFlush ? (capEnd - Theme.dockRadius - currentEnd) : (currentAlong - capStart - Theme.dockRadius)
    // The far side's fillet shrinks away as that side nears the rounded corner
    readonly property real farFillet: (startFlush || endFlush) ? Math.max(0, Math.min(filletSize, farRoom)) : (fitsOnDock ? filletSize : 0)
    // How far the far side reaches past the other end of the dock
    readonly property real farOverhang: (startFlush || endFlush) ? Math.max(0, -farRoom - Theme.dockRadius) : 0
}
