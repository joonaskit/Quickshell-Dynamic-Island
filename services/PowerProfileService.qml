pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "refreshRate.js" as RefreshRate

Singleton {
    id: root

    property string activeProfile: "balanced"
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isPresent

    // 60 Hz on battery: the rates of the lowered built-in panels by output name, as { from, to }. Kept in a
    // state file, so a restart on battery does not forget what to go back to
    property var rememberedRates: ({})
    property bool refreshPending: false
    property bool rememberedLoaded: false
    // UPower.onBattery reads false until D-Bus answers, so a check before then would raise a lowered panel.
    // If it answers later than the timer below, the panel goes up and back down once
    property bool upowerSettled: false
    readonly property bool refreshReady: upowerSettled && rememberedLoaded && SettingsService.isLoaded
    onRefreshReadyChanged: root.updateRefreshRate()
    // Why the setting cannot work here, or "" when it can
    readonly property string lowRefreshProblem: DepsService.problem(["kscreen-doctor"])
    readonly property bool lowRefreshAvailable: lowRefreshProblem === ""

    // Follows power-profiles-daemon's change signals through Quickshell, so nothing polls it.
    // Quickshell never listens if the daemon was not there when the shell started, so the
    // profile is also read once at start and after each change made here.
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            root.profileSignals++;
            root.activeProfile = root.profileName(PowerProfiles.profile);
        }
    }

    // Signals seen, and how many there were when the running read started
    property int profileSignals: 0
    property int readSignals: 0

    function profileName(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return "power-saver";
        case PowerProfile.Performance: return "performance";
        default: return "balanced";
        }
    }

    Process {
        id: queryProc
        command: ["busctl", "--system", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        stdout: StdioCollector {
            onStreamFinished: {
                // A signal that came in during the read is newer than its reply. Format: s "performance"
                let match = text.trim().match(/"([^"]+)"/);
                if (match && root.readSignals === root.profileSignals) root.activeProfile = match[1];
            }
        }
    }

    Component.onCompleted: root.queryProfile()

    function queryProfile() {
        if (queryProc.running) return;
        root.readSignals = root.profileSignals;
        queryProc.running = true;
    }

    function setProfile(profileName) {
        if (root.profiles.indexOf(profileName) < 0) return;
        root.activeProfile = profileName;
        setProc.command = ["busctl", "--system", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", profileName];
        setProc.running = true;
    }

    Process {
        id: setProc
        onExited: root.queryProfile()
    }

    // Lower the built-in screen's refresh rate while on battery, and put it back on AC
    Connections {
        target: UPower
        function onOnBatteryChanged() { root.updateRefreshRate(); }
    }

    Connections {
        target: SettingsService
        function onLowRefreshOnBatteryChanged() { root.updateRefreshRate(); }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: root.upowerSettled = true
    }

    function updateRefreshRate() {
        if (!RefreshRate.shouldCheck(root.refreshReady, root.lowRefreshAvailable, SettingsService.lowRefreshOnBattery, root.rememberedRates)) return;
        if (displayProc.running || applyProc.running) root.refreshPending = true;
        else displayProc.running = true;
    }

    function runPendingRefresh() {
        if (!root.refreshPending || displayProc.running || applyProc.running) return;
        root.refreshPending = false;
        displayProc.running = true;
    }

    // Written before the mode changes, so a crash in between cannot lose the rate to go back to
    function setRememberedRates(rates) {
        if (JSON.stringify(rates) === JSON.stringify(root.rememberedRates)) return;
        root.rememberedRates = rates;
        rememberedFile.setText(JSON.stringify(rates));
    }

    FileView {
        id: rememberedFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-island/refresh-rate.json"
        blockWrites: true
        printErrors: false
        onLoaded: {
            root.rememberedRates = RefreshRate.parseRemembered(text());
            root.rememberedLoaded = true;
        }
        onLoadFailed: root.rememberedLoaded = true
    }

    Process {
        id: displayProc
        command: ["kscreen-doctor", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let outputs = [];
                try {
                    outputs = JSON.parse(text).outputs || [];
                } catch (e) {
                    return;
                }
                let lower = SettingsService.lowRefreshOnBattery && UPower.onBattery;
                let plan = RefreshRate.plan(outputs, lower, root.rememberedRates);
                root.setRememberedRates(plan.remembered);
                if (plan.changes.length === 0) return;
                applyProc.command = ["kscreen-doctor"].concat(RefreshRate.commandArgs(plan.changes));
                applyProc.running = true;
            }
        }
        onExited: root.runPendingRefresh()
    }

    // A check waits for this, as one that reads a panel mid-switch would plan from the old rate
    Process {
        id: applyProc
        onExited: root.runPendingRefresh()
    }
}
