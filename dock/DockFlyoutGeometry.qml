import ".."
import QtQuick

// Geometry for a popup that grows out of the dock: its base stays flush on the
// dock edge and it spreads from the origin point (e.g. the clicked icon) to its
// final size. Bind the popup's x / y / width / height to the outputs.
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

    // Morph progress: 0 = flush with the dock at the origin, 1 = fully open
    property real progress: open ? 1.0 : 0.0
    Behavior on progress {
        NumberAnimation {
            duration: geo.open ? Theme.animDuration : Theme.animDurationFast
            easing.type: geo.open ? Theme.animEasing : Easing.OutCubic
            easing.overshoot: Theme.animOvershoot
        }
    }

    // Dock edge the popup grows from
    readonly property real dockTop: dockCapsuleY > 0 ? dockCapsuleY : (parentHeight - Theme.dockHeight)
    readonly property real dockSideEdge: dockPosition === "left" ? (dockCapsuleX + dockCapsuleWidth) : dockCapsuleX

    // Extent of the dock's straight edge (inside its rounded corners), along the dock
    readonly property real edgeStart: (isVertical ? dockCapsuleY : dockCapsuleX) + Theme.dockRadius + filletSize
    readonly property real edgeEnd: (isVertical ? (dockCapsuleY + dockCapsuleHeight) : (dockCapsuleX + dockCapsuleWidth)) - Theme.dockRadius - filletSize
    readonly property real alongLength: isVertical ? finalHeight : finalWidth
    // False when the dock is too short to carry the whole popup on its straight edge
    readonly property bool fitsOnDock: (edgeEnd - edgeStart) >= alongLength

    // Final position along the dock: centred on the origin, kept on the straight edge
    readonly property real finalAlong: {
        let center = isVertical ? targetY : targetX;
        let pos;
        if (fitsOnDock) {
            pos = Math.max(edgeStart, Math.min(edgeEnd - alongLength, center - alongLength / 2));
        } else {
            let capStart = isVertical ? dockCapsuleY : dockCapsuleX;
            let capLen = isVertical ? dockCapsuleHeight : dockCapsuleWidth;
            pos = capStart + (capLen - alongLength) / 2;
        }
        let limit = (isVertical ? parentHeight : parentWidth) - alongLength - 8;
        return Math.max(8, Math.min(limit, pos));
    }

    readonly property real originAlong: (isVertical ? targetY : targetX) - originSize / 2
    readonly property real currentAlong: originAlong + (finalAlong - originAlong) * progress
    readonly property real currentAlongLength: originSize + (alongLength - originSize) * progress
    // Distance grown away from the dock
    readonly property real currentAway: (isVertical ? finalWidth : finalHeight) * progress

    // Outputs
    readonly property real x: isVertical ? (dockPosition === "left" ? dockSideEdge : (dockSideEdge - currentAway)) : currentAlong
    readonly property real y: isVertical ? currentAlong : (dockTop - currentAway)
    readonly property real width: isVertical ? currentAway : currentAlongLength
    readonly property real height: isVertical ? currentAlongLength : currentAway

    // Where full-size content sits inside the growing body: centred along the dock
    // and pinned to the leading edge, so it rides out with the popup
    readonly property real contentX: isVertical ? (dockPosition === "left" ? (width - finalWidth) : 0) : (width - finalWidth) / 2
    readonly property real contentY: isVertical ? (height - finalHeight) / 2 : 0
    readonly property real contentOpacity: Math.max(0, Math.min(1, (progress - 0.4) / 0.6))
}
