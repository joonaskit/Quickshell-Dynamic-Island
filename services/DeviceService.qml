pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var devices: []
    property int deviceCount: 0
    property int mountedCount: 0
    property bool hasDevices: deviceCount > 0
    property bool hasMountedDevices: mountedCount > 0

    property string operatingDevice: ""
    property string statusMessage: ""

    function updateDevices(list) {
        if (!list || !Array.isArray(list)) {
            list = [];
        }
        root.devices = list;
        root.deviceCount = list.length;
        let mCount = 0;
        for (let i = 0; i < list.length; i++) {
            let dev = list[i];
            if (dev.partitions && Array.isArray(dev.partitions)) {
                for (let j = 0; j < dev.partitions.length; j++) {
                    if (dev.partitions[j].isMounted) {
                        mCount++;
                    }
                }
            } else if (dev.isMounted) {
                mCount++;
            }
        }
        root.mountedCount = mCount;
    }

    // Process restart timer
    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!monitorProc.running) {
                monitorProc.running = true;
            }
        }
    }

    // Background monitor process: streams device list when added/removed/mounted/unmounted
    Process {
        id: monitorProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/devices.py", "monitor"]
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
                        let list = JSON.parse(t);
                        root.updateDevices(list);
                    } catch(e) {}
                }
            }
        }
    }

    // One-shot scan process for explicit manual refresh
    Process {
        id: scanProc
        command: ["python3", Quickshell.shellDir + "/scripts/devices.py", "list"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    try {
                        let list = JSON.parse(text.trim());
                        root.updateDevices(list);
                    } catch(e) {}
                }
            }
        }
    }

    function scanDevices() {
        if (!scanProc.running) {
            scanProc.running = true;
        }
    }

    // Periodic safety poll
    Timer {
        id: safetyPollTimer
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            if (!monitorProc.running) {
                root.scanDevices();
            }
        }
    }

    // Execute mount/unmount/power-off action
    function mountDevice(path) {
        if (!path) return;
        root.operatingDevice = path;
        root.statusMessage = "Mounting...";
        let cmd = ["python3", Quickshell.shellDir + "/scripts/devices.py", "mount", path];
        let p = Qt.createQmlObject('import Quickshell.Io; Process { running: true; }', root);
        p.command = cmd;
        p.exited.connect(function() {
            root.operatingDevice = "";
            root.statusMessage = "";
            root.scanDevices();
            p.destroy(100);
        });
    }

    function unmountDevice(path) {
        if (!path) return;
        root.operatingDevice = path;
        root.statusMessage = "Unmounting...";
        let cmd = ["python3", Quickshell.shellDir + "/scripts/devices.py", "unmount", path];
        let p = Qt.createQmlObject('import Quickshell.Io; Process { running: true; }', root);
        p.command = cmd;
        p.exited.connect(function() {
            root.operatingDevice = "";
            root.statusMessage = "";
            root.scanDevices();
            p.destroy(100);
        });
    }

    function powerOffDevice(path) {
        if (!path) return;
        root.operatingDevice = path;
        root.statusMessage = "Safely removing...";
        let cmd = ["python3", Quickshell.shellDir + "/scripts/devices.py", "power-off", path];
        let p = Qt.createQmlObject('import Quickshell.Io; Process { running: true; }', root);
        p.command = cmd;
        p.exited.connect(function() {
            root.operatingDevice = "";
            root.statusMessage = "";
            root.scanDevices();
            p.destroy(100);
        });
    }

    function openDevice(mountpoint) {
        if (!mountpoint) return;
        let cmd = ["python3", Quickshell.shellDir + "/scripts/devices.py", "open", mountpoint];
        let p = Qt.createQmlObject('import Quickshell.Io; Process { running: true; }', root);
        p.command = cmd;
        p.exited.connect(function() {
            p.destroy(100);
        });
    }

    Component.onCompleted: {
        root.scanDevices();
    }
}
