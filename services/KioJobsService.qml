pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// File copies and moves from KDE apps, shown as activities (docs/KIO_JOBS.md).
// scripts/kio_jobs.py takes the names KIO reports its jobs to and forwards each
// job through the Activities API, so this only runs it and keeps its state.
Singleton {
    id: root

    // While it runs, KIO apps leave their own progress window out, so it only
    // runs while the island has somewhere to show the jobs
    readonly property bool wanted: SettingsService.kioJobActivities
        && (SettingsService.showActivitiesInPill || SettingsService.isWidgetEnabled("activities"))

    // "active", "waiting" (another program shows KIO's jobs), or "" when not running
    property string state: ""

    onWantedChanged: root.apply()
    onStateChanged: HelperService.setStatus("kiojobs", { note: root.state === "waiting" ? "Waiting, another program shows file progress" : "" })

    function apply() {
        HelperService.setStatus("kiojobs", { off: !root.wanted });
        if (!root.wanted) restartTimer.stop();
        helperProc.running = root.wanted;
    }

    function handleLine(line) {
        let t = line.trim();
        if (t.length === 0) return;
        try {
            let data = JSON.parse(t);
            if (data.type === "status") root.state = data.state;
        } catch (e) {
            console.warn("[KioJobsService] Error parsing helper output:", e);
        }
    }

    Process {
        id: helperProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/kio_jobs.py"]
        Component.onCompleted: {
            HelperService.watch("kiojobs", "File progress", helperProc);
            root.apply();
        }

        property real startedAt: 0
        property int quickExits: 0

        onRunningChanged: {
            if (running) {
                startedAt = Date.now();
                return;
            }
            root.state = "";
            if (!root.wanted) return;
            // Back off when it keeps dying right away, for example without python-dbus
            quickExits = (Date.now() - startedAt < 5000) ? quickExits + 1 : 0;
            restartTimer.interval = Math.min(30000, 1000 * Math.pow(2, Math.min(quickExits, 5)));
            restartTimer.start();
        }

        stdout: SplitParser {
            onRead: function(line) { root.handleLine(line); }
        }

        stderr: SplitParser {
            onRead: function(line) { console.warn("[KioJobsService]", line); }
        }
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: if (root.wanted) helperProc.running = true
    }
}
