pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// The dependency check (scripts/check_deps.py --json) run once at startup, and
// again on request. The welcome guide shows the whole report; the status icons
// use it to tell whether the tools they need are installed.
Singleton {
    id: root

    // The parsed report, or null before the first check and when it cannot run
    property var report: null
    property bool checkFailed: false
    readonly property bool checking: checkProc.running

    function runCheck() {
        if (!checkProc.running) checkProc.running = true;
    }

    // The dependencies from `ids` that were not found. Empty while the result is unknown
    function missingOf(ids) {
        if (!root.report || !ids) return [];
        return root.report.dependencies.filter(d => ids.indexOf(d.id) >= 0 && d.status !== "found");
    }

    // True when none of the alternatives in `ids` is usable, so the feature cannot work.
    // Never true before the check has finished, so icons do not flash as unavailable.
    function noneUsable(ids) {
        return !!ids && ids.length > 0 && root.missingOf(ids).length === ids.length;
    }

    // Status icon `id` (a StatusIconRegistry id) needs a tool that is missing
    function iconUnavailable(id) {
        let entry = StatusIconRegistry.byId(id);
        return !!entry && root.noneUsable(entry.requires);
    }

    // One line for the settings list: what is missing and how to install it
    function iconProblem(id) {
        let entry = StatusIconRegistry.byId(id);
        if (!entry || !root.noneUsable(entry.requires)) return "";
        return root.missingOf(entry.requires).map(d => d.status === "not-running" ? d.name + " is installed but not running" : d.name + " is not installed" + (d.package ? " (package: " + d.package + ")" : "")).join(", or ");
    }

    Component.onCompleted: root.runCheck()

    Process {
        id: checkProc
        // Exits 1 when something required is missing, but still prints the report
        command: ["python3", Quickshell.shellDir + "/scripts/check_deps.py", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim());
                    if (parsed && Array.isArray(parsed.dependencies)) {
                        root.report = parsed;
                        root.checkFailed = false;
                        return;
                    }
                } catch (e) {}
                root.report = null;
                root.checkFailed = true;
            }
        }
    }
}
