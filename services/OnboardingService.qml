pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// The welcome guide (OnboardingWindow): whether it is open, which step it is on
// and the dependency check it shows. It opens by itself once, on a new install,
// and again from the About settings page or the "onboarding open" IPC call.
Singleton {
    id: root

    readonly property var steps: ["Welcome", "System check", "Import", "Setup", "Tips", "Done"]

    property bool open: false
    property int step: 0
    property bool decided: false

    // Result of scripts/check_deps.py --json, or null before the first check and when it cannot run
    property var report: null
    property bool checkFailed: false
    readonly property bool checking: checkProc.running
    readonly property var problems: root.report ? root.report.dependencies.filter(d => d.status !== "found") : []
    readonly property var importantProblems: root.problems.filter(d => d.severity !== "optional")
    readonly property var optionalProblems: root.problems.filter(d => d.severity === "optional")

    // The text last copied with copy(), cleared after a moment so its button can say "Copied"
    property string copied: ""

    function show() {
        root.step = 0;
        root.open = true;
        root.runCheck();
    }

    // Closing at any step counts as done, so the guide does not come back by itself
    function close() {
        root.open = false;
        SettingsService.setSetting("onboardingVersion", SettingsService.onboardingCurrent);
    }

    function goTo(index) {
        root.step = Math.max(0, Math.min(root.steps.length - 1, index));
    }

    function next() {
        if (root.step >= root.steps.length - 1) root.close();
        else root.goTo(root.step + 1);
    }

    function back() {
        root.goTo(root.step - 1);
    }

    function runCheck() {
        if (!checkProc.running) checkProc.running = true;
    }

    function copy(text) {
        copyProc.command = ["wl-copy", "--", text];
        copyProc.running = true;
        root.copied = text;
        copiedTimer.restart();
    }

    // Opens the guide once the settings are known and say it has not been shown
    Connections {
        target: SettingsService
        function onSettingsChanged() {
            if (!SettingsService.isLoaded || root.decided) return;
            root.decided = true;
            if (SettingsService.onboardingVersion < SettingsService.onboardingCurrent) root.show();
        }
    }

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

    Process {
        id: copyProc
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.copied = ""
    }
}
