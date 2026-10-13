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

    // The dependency check lives in DepsService, which also feeds the status icons
    readonly property var report: DepsService.report
    readonly property bool checkFailed: DepsService.checkFailed
    readonly property bool checking: DepsService.checking
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
        DepsService.runCheck();
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
        id: copyProc
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.copied = ""
    }
}
