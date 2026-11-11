pragma Singleton
import ".."
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

    // The busiest programs, as [{ name, cpu, memMb }] (scripts/top_processes.py). Only
    // sampled while something sets watchProcesses, which the dial's hardware page does.
    property bool watchProcesses: false
    property var processes: []

    readonly property string systemMonitorProblem: DepsService.problem(["plasma-systemmonitor"])

    Process {
        id: topProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/top_processes.py"]
        running: root.watchProcesses
        onRunningChanged: if (!running) root.processes = []

        stdout: SplitParser {
            onRead: function(line) {
                try {
                    root.processes = JSON.parse(line).processes || [];
                } catch (e) {}
            }
        }
    }

    function openSystemMonitor() {
        Quickshell.execDetached(["plasma-systemmonitor"]);
    }

    // Asks every process of a program to quit (SIGTERM), as named in `processes`
    function endProgram(name) {
        Quickshell.execDetached(["pkill", "-x", "--", name]);
    }

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
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/hardware_stats.py"]
        running: true

        Component.onCompleted: HelperService.watch("hardware", "Hardware stats", statsProc)

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
