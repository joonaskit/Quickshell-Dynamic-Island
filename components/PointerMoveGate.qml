import QtQuick

// Tells a pointer that moved from rows that moved under a still pointer. When the
// keyboard scrolls a list, or a filter changes it, rows slide under the pointer and Qt
// sends them hover events as if it had moved; a list that selects the hovered row
// would then take the selection away from the keyboard. Taken from Omarchy's shell.
//
// Select from the row MouseArea's onPositionChanged, only when moved() says so:
//
//     onPositionChanged: mouse => { if (gate.moved(this, mouse)) view.currentIndex = index; }
//
// Positions are compared in `referenceItem`, which must not move with the rows or the
// panel: the window's `Window.contentItem`. Then a scroll or an opening animation
// leaves the position as it was and needs no reset. Call reset() when the list opens,
// so a pointer that moved while it was closed does not count on its first sample.
QtObject {
    id: root

    property Item referenceItem: null
    // Pixels the pointer must move in either direction to count
    property real threshold: 1

    property bool primed: false
    property real lastX: 0
    property real lastY: 0

    function reset() {
        root.primed = false;
        root.lastX = 0;
        root.lastY = 0;
    }

    // True when the pointer moved since the last sample. The first sample after a
    // reset only records where it is.
    function moved(item, mouse) {
        if (!item || !mouse) {
            root.reset();
            return false;
        }
        let point = item.mapToItem(root.referenceItem || item, mouse.x, mouse.y);
        if (!root.primed) {
            root.primed = true;
            root.lastX = point.x;
            root.lastY = point.y;
            return false;
        }
        let didMove = Math.abs(point.x - root.lastX) > root.threshold || Math.abs(point.y - root.lastY) > root.threshold;
        // Sub-threshold steps keep the last accepted position, so a slow drift adds up
        if (didMove) {
            root.lastX = point.x;
            root.lastY = point.y;
        }
        return didMove;
    }
}
