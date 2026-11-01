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

    // 60 Hz on battery: the rates of the lowered built-in panels by output name, as { from, to }. Kept in a
    // state file, so a restart on battery does not forget what to go back to
    property var rememberedRates: ({})
    property bool refreshPending: false

    // Process to query active profile
    Process {
        id: queryProc
        command: ["busctl", "--system", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                let t = line.trim();
                // Format: s "performance"
                let match = t.match(/"([^"]+)"/);
                if (match && match[1]) {
                    root.activeProfile = match[1];
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            root.queryProfile();
        }
    }

    Component.onCompleted: {
        root.queryProfile();
    }

    function queryProfile() {
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    function setProfile(profileName) {
        root.activeProfile = profileName;
        let p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["busctl", "--system", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", "' + profileName + '"]; running: true; }', root);
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.queryProfile();
        }
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

    function updateRefreshRate() {
        if (!SettingsService.lowRefreshOnBattery && Object.keys(root.rememberedRates).length === 0) return;
        if (displayProc.running) root.refreshPending = true;
        else displayProc.running = true;
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
        onLoaded: root.rememberedRates = RefreshRate.parseRemembered(text())
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
                if (plan.changes.length > 0) Quickshell.execDetached(["kscreen-doctor"].concat(RefreshRate.commandArgs(plan.changes)));
            }
        }
        onExited: {
            if (!root.refreshPending) return;
            root.refreshPending = false;
            running = true;
        }
    }
}
