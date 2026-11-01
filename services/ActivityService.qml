pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Activities that other apps publish over D-Bus (docs/ACTIVITIES_API.md).
// scripts/activities_bridge.py owns the bus name and validates what clients
// send; this singleton holds the list it reports, in the order the pill favours.
Singleton {
    id: root

    // Newest state from the bridge: failed first, then priority, then newest
    property var activities: []
    property bool bridgeRunning: false

    readonly property int count: root.activities.length
    readonly property var current: root.activities.length > 0 ? root.activities[0] : null
    readonly property bool hasFailed: root.current !== null && root.current.state === "failed"

    // Pill priority is timer, then activity, then media. A failed activity
    // outranks all of them, so the user can't miss that something went wrong.
    readonly property bool showInPill: SettingsService.showActivitiesInPill
        && root.current !== null
        && (root.hasFailed || TimerService.pillMode === "")

    function accentFor(state) {
        if (state === "failed") return Theme.accentRed;
        if (state === "done") return Theme.accentGreen;
        if (state === "cancelled") return Theme.accentOrange;
        return Theme.accentBlue;
    }

    // What the pill and cards say about the state, for activities that give no text of their own
    function stateLabel(activity) {
        if (activity.state === "failed") return activity.error !== "" ? activity.error : "Failed";
        if (activity.state === "done") return "Done";
        if (activity.state === "cancelled") return "Cancelled";
        return "";
    }

    // Ask the owning app to run one of the activity's actions
    function invoke(key, action) {
        root.send({ "cmd": "action", "key": key, "action": action });
    }

    // Remove an activity; the owning app is told it was dismissed
    function dismiss(key) {
        root.send({ "cmd": "dismiss", "key": key });
    }

    function send(command) {
        if (!bridge.running) return;
        bridge.write(JSON.stringify(command) + "\n");
    }

    function handleLine(line) {
        let t = line.trim();
        if (t.length === 0) return;
        try {
            let data = JSON.parse(t);
            if (data.type === "state" && Array.isArray(data.activities)) {
                root.activities = data.activities;
            }
        } catch (e) {
            console.warn("[ActivityService] Error parsing bridge output:", e);
        }
    }

    HelperProcess {
        id: bridge
        helperId: "activities"
        helperName: "Activities bridge"
        restartDelay: 1000
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/activities_bridge.py"]
        stdinEnabled: true

        onRunningChanged: {
            root.bridgeRunning = running;
            // The bridge's state is gone with it
            if (!running) root.activities = [];
        }

        stdout: SplitParser {
            onRead: function(line) { root.handleLine(line); }
        }

        stderr: SplitParser {
            onRead: function(line) { console.warn("[ActivityService]", line); }
        }
    }
}
