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

    onStateChanged: HelperService.setStatus("kiojobs", { note: root.state === "waiting" ? "Waiting, another program shows file progress" : "" })

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

    HelperProcess {
        id: helperProc
        helperId: "kiojobs"
        helperName: "File progress"
        restartDelay: 1000
        wanted: root.wanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/kio_jobs.py"]
        onRunningChanged: if (!running) root.state = ""

        stdout: SplitParser {
            onRead: function(line) { root.handleLine(line); }
        }

        stderr: SplitParser {
            onRead: function(line) { console.warn("[KioJobsService]", line); }
        }
    }
}
