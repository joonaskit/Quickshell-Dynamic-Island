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

    // The dependencies from `ids` that were not found. Empty while the result is unknown.
    // One made for another desktop ("not-needed", e.g. KWin under niri) counts too: the
    // feature that needs it cannot work here either.
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
        return entry ? root.problem(entry.requires) : "";
    }

    // What is missing from the alternatives in `ids` and how to install it, or "" when one is usable
    function problem(ids) {
        if (!root.noneUsable(ids)) return "";
        return root.missingOf(ids).map(d => root.describe(d)).join(", or ");
    }

    function describe(d) {
        if (d.status === "not-running") return d.name + " is installed but not running";
        if (d.status === "not-needed") return "Needs " + d.name + ", which is for " + root.desktopNames(d.desktops) + " only";
        return d.name + " is not installed" + (d.package ? " (package: " + d.package + ")" : "");
    }

    function desktopNames(desktops) {
        let names = { "kde": "KDE Plasma", "niri": "niri", "other": "other desktops" };
        return (desktops || []).map(d => names[d] || d).join(" and ");
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
