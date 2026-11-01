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

    // 60 Hz on battery: the modes the built-in panels had before they were lowered, by output name
    property var rememberedModes: ({})
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
        if (!SettingsService.lowRefreshOnBattery && Object.keys(root.rememberedModes).length === 0) return;
        if (displayProc.running) root.refreshPending = true;
        else displayProc.running = true;
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
                let plan = RefreshRate.plan(outputs, lower, root.rememberedModes);
                root.rememberedModes = plan.remembered;
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
