import ".."
import QtQuick
import Quickshell.Io
import "../services/restartDelay.js" as RestartDelay

// A long-running helper (docs/HELPERS.md). Runs while `wanted`, starts again when it exits,
// backing off if it keeps dying right away, and registers with HelperService. `running` is
// set by hand, since HelperService.restartAll assigns it too, which would break a binding.
Process {
    id: helper

    property string helperId: ""
    property string helperName: ""
    property int restartDelay: 2000
    property bool wanted: true

    property real startedAt: 0
    property int quickExits: 0

    // Timed from the attempt, as a command that fails to start never reports running
    function start() {
        startedAt = Date.now();
        running = true;
    }

    function apply() {
        HelperService.setStatus(helperId, { off: !wanted });
        if (wanted) {
            start();
        } else {
            restartTimer.stop();
            running = false;
        }
    }

    onWantedChanged: apply()
    onRunningChanged: {
        if (running) {
            startedAt = Date.now();
            return;
        }
        if (!wanted) return;
        quickExits = RestartDelay.countQuickExits(quickExits, Date.now() - startedAt);
        restartTimer.interval = RestartDelay.delay(restartDelay, quickExits);
        restartTimer.start();
    }

    // Process has no default property, so the timer is held in one
    property Timer restartTimer: Timer {
        repeat: false
        onTriggered: if (helper.wanted) helper.start()
    }

    Component.onCompleted: {
        HelperService.watch(helperId, helperName, helper);
        apply();
    }
}
