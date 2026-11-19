import QtQuick
import Quickshell

// Runs a fixture's checks in order and reports the result for tests/run_fixtures.sh.
// Each step is { name, run: function(), until: function() -> bool }: `run` acts
// (optional), then the step waits until `until` holds (optional), failing after
// `timeout` ms. `until` may call fail(reason) itself to stop at once.
//
// It checks `until` on a short timer. That is fine in a test: a step waits on state
// that may change through any signal, and the timer only runs while the fixture does.
Item {
    id: root

    property var steps: []
    property int timeout: 3000
    // Set by the runner: a directory of the fixture's own to write files in
    readonly property string work: Quickshell.env("FIXTURE_WORK") || ""

    property int index: -1
    property double stepStart: 0
    property bool done: false

    function pass() {
        if (root.done) return;
        root.done = true;
        console.info("RESULT pass");
        Qt.quit();
    }

    function fail(reason) {
        if (root.done) return;
        root.done = true;
        let step = root.index >= 0 && root.index < root.steps.length ? root.steps[root.index].name + ": " : "";
        console.info("RESULT fail " + step + reason);
        Qt.quit();
    }

    // True when actual is expected; otherwise fails, naming what was compared
    function expect(what, actual, expected) {
        if (actual === expected) return true;
        root.fail(what + " is " + root.show(actual) + ", expected " + root.show(expected));
        return false;
    }

    // Objects print by type: QML items do not convert to JSON
    function show(value) {
        return typeof value === "object" && value !== null ? String(value) : JSON.stringify(value);
    }

    function next() {
        root.index++;
        if (root.index >= root.steps.length) {
            root.pass();
            return;
        }
        root.stepStart = Date.now();
        let step = root.steps[root.index];
        try {
            if (step.run) step.run();
        } catch (e) {
            root.fail(String(e));
            return;
        }
        check.restart();
    }

    Timer {
        id: check
        interval: 20
        repeat: true
        onTriggered: {
            if (root.done) {
                stop();
                return;
            }
            let step = root.steps[root.index];
            let ok = false;
            try {
                ok = !step.until || step.until();
            } catch (e) {
                root.fail(String(e));
                return;
            }
            if (root.done) return;
            if (ok) {
                stop();
                root.next();
            } else if (Date.now() - root.stepStart > root.timeout) {
                root.fail("timed out after " + root.timeout + " ms");
            }
        }
    }

    // Start once the fixture's own objects are complete
    Component.onCompleted: Qt.callLater(root.next)
}
