pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string activeProfile: "balanced"
    readonly property var profiles: ["power-saver", "balanced", "performance"]

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
}
