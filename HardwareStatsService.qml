pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpuPercent: 0
    property int ramPercent: 0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property int cpuTemp: 0

    // Process restart timer
    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!statsProc.running) {
                statsProc.running = true;
            }
        }
    }

    Process {
        id: statsProc
        command: ["python3", "-u", Quickshell.shellDir + "/hardware_stats.py"]
        running: true

        onRunningChanged: {
            if (!running) {
                restartTimer.start();
            }
        }

        stdout: SplitParser {
            onRead: function(line) {
                let t = line.trim();
                if (t.length > 0) {
                    try {
                        let data = JSON.parse(t);
                        root.cpuPercent = data.cpu || 0;
                        root.ramPercent = data.ram || 0;
                        root.ramUsedGb = data.ramUsed || 0.0;
                        root.ramTotalGb = data.ramTotal || 0.0;
                        root.cpuTemp = data.temp || 0;
                    } catch(e) {}
                }
            }
        }
    }
}
