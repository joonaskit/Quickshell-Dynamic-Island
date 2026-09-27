pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isAvailable: true
    property bool isEnabled: true
    property bool isConnected: false
    property var pairedDevices: []
    property var connectedDevices: []
    property string connectingMac: ""

    Timer {
        id: pollTimer
        interval: 3500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.queryBluetooth();
        }
    }

    Process {
        id: queryProc
        command: ["sh", "-c", "echo POWER:$(bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}'); echo CONNECTED:; bluetoothctl devices Connected 2>/dev/null; echo PAIRED:; bluetoothctl devices Paired 2>/dev/null"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let full = text.trim();
                    let powerPart = "";
                    let connPart = "";
                    let pairedPart = "";

                    let cIdx = full.indexOf("CONNECTED:");
                    let pIdx = full.indexOf("PAIRED:");

                    if (cIdx !== -1 && pIdx !== -1) {
                        powerPart = full.substring(0, cIdx).trim();
                        connPart = full.substring(cIdx + 10, pIdx).trim();
                        pairedPart = full.substring(pIdx + 7).trim();
                    }

                    root.isEnabled = powerPart.includes("POWER:yes");

                    let connectedMap = {};
                    let connList = [];
                    if (connPart.length > 0) {
                        let lines = connPart.split("\n");
                        for (let i = 0; i < lines.length; i++) {
                            let l = lines[i].trim();
                            if (l.startsWith("Device ")) {
                                let parts = l.split(" ");
                                let mac = parts[1];
                                let name = parts.slice(2).join(" ");
                                connectedMap[mac] = true;
                                connList.push({ mac: mac, name: name });
                            }
                        }
                    }
                    root.connectedDevices = connList;
                    root.isConnected = connList.length > 0;

                    let pairedList = [];
                    if (pairedPart.length > 0) {
                        let lines = pairedPart.split("\n");
                        for (let i = 0; i < lines.length; i++) {
                            let l = lines[i].trim();
                            if (l.startsWith("Device ")) {
                                let parts = l.split(" ");
                                let mac = parts[1];
                                let name = parts.slice(2).join(" ");
                                pairedList.push({
                                    mac: mac,
                                    name: name,
                                    isConnected: !!connectedMap[mac]
                                });
                            }
                        }
                    }
                    // Sort connected devices first
                    pairedList.sort(function(a, b) {
                        if (a.isConnected && !b.isConnected) return -1;
                        if (!a.isConnected && b.isConnected) return 1;
                        return a.name.localeCompare(b.name);
                    });
                    root.pairedDevices = pairedList;
                }
            }
        }
    }

    Process {
        id: toggleProc
        onExited: {
            root.queryBluetooth();
        }
    }

    Process {
        id: actionProc
        onExited: {
            root.connectingMac = "";
            root.queryBluetooth();
        }
    }

    Process {
        id: settingsProc
        command: ["kcmshell6", "kcm_bluetooth"]
    }

    function queryBluetooth() {
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    function togglePower() {
        let next = root.isEnabled ? "off" : "on";
        root.isEnabled = !root.isEnabled;
        toggleProc.command = ["bluetoothctl", "power", next];
        toggleProc.running = true;
    }

    function connectDevice(mac) {
        root.connectingMac = mac;
        actionProc.command = ["bluetoothctl", "connect", mac];
        actionProc.running = true;
    }

    function disconnectDevice(mac) {
        actionProc.command = ["bluetoothctl", "disconnect", mac];
        actionProc.running = true;
    }

    function toggleConnection(mac, isCurrentlyConnected) {
        if (isCurrentlyConnected) {
            disconnectDevice(mac);
        } else {
            connectDevice(mac);
        }
    }

    function openSettings() {
        settingsProc.running = true;
    }
}
