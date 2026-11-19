import QtQuick
import QtTest
import "../components"

TestCase {
    name: "PointerMoveGate"

    // A list view with one row; the row moves inside it as a scroll would
    Item {
        id: view
        width: 200
        height: 200

        Item {
            id: row
            width: 200
            height: 40
        }
    }

    PointerMoveGate {
        id: gate
        referenceItem: view
    }

    PointerMoveGate {
        id: ownGate
    }

    function init() {
        row.y = 0;
        gate.reset();
        ownGate.reset();
    }

    // Where the pointer is in the row when it is at (x, y) in the view
    function at(x, y) {
        return { "x": x - row.x, "y": y - row.y };
    }

    function test_firstSampleDoesNotCount() {
        verify(!gate.moved(row, at(10, 10)));
    }

    function test_movingCounts() {
        gate.moved(row, at(10, 10));
        verify(gate.moved(row, at(10, 14)));
        verify(gate.moved(row, at(16, 14)));
    }

    function test_samePlaceDoesNotCount() {
        gate.moved(row, at(10, 10));
        verify(!gate.moved(row, at(10, 10)));
    }

    function test_rowsMovingUnderAStillPointerDoNotCount() {
        gate.moved(row, at(10, 30));
        // The keyboard scrolls the list: the row moves up, the pointer stays
        row.y = -20;
        verify(!gate.moved(row, at(10, 30)));
        row.y = -60;
        verify(!gate.moved(row, at(10, 30)));
    }

    function test_jitterWithinTheThresholdDoesNotCount() {
        gate.moved(row, at(10, 10));
        verify(!gate.moved(row, at(10.5, 10.8)));
        verify(!gate.moved(row, at(9.5, 10)));
    }

    function test_slowDriftAddsUp() {
        gate.moved(row, at(10, 10));
        verify(!gate.moved(row, at(10, 10.6)));
        verify(gate.moved(row, at(10, 11.2)));
    }

    function test_resetForgetsThePosition() {
        gate.moved(row, at(10, 10));
        gate.reset();
        verify(!gate.moved(row, at(50, 50)));
        verify(gate.moved(row, at(50, 60)));
    }

    function test_missingEventResets() {
        gate.moved(row, at(10, 10));
        verify(!gate.moved(row, null));
        verify(!gate.moved(row, at(80, 80)));
    }

    function test_withoutReferenceItemUsesTheRow() {
        ownGate.moved(row, { "x": 5, "y": 5 });
        verify(ownGate.moved(row, { "x": 5, "y": 9 }));
    }
}
