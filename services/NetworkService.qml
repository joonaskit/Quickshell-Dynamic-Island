pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isConnected: false
    property bool isWifi: false
    property bool isWifiEnabled: true
    property string ssid: ""
    property int signalBars: 3   // 1 to 4
    property int signalPercent: 80
    property var availableNetworks: []
    property bool isScanning: false
    property string connectingSsid: ""

    Timer {
        id: pollTimer
        interval: 3500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.queryNetwork();
        }
    }

    // Query active device status & radio power
    Process {
        id: statusProc
        command: ["sh", "-c", "echo WIFI_RADIO:$(nmcli radio wifi 2>/dev/null); nmcli -t -f TYPE,STATE,CONNECTION dev status 2>/dev/null | grep -E '^(wifi|ethernet):connected' | head -n1"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let lines = text.trim().split("\n");
                    let foundActive = false;
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i];
                        if (line.startsWith("WIFI_RADIO:")) {
                            root.isWifiEnabled = line.includes("enabled");
                        } else {
                            let parts = line.split(":");
                            if (parts.length >= 3) {
                                foundActive = true;
                                root.isConnected = true;
                                root.isWifi = parts[0] === "wifi";
                                root.ssid = parts[2];
                            }
                        }
                    }
                    if (!foundActive) {
                        root.isConnected = false;
                        root.isWifi = false;
                        root.ssid = "";
                    }
                }
            }
        }
        onExited: {
            if (root.isConnected && root.isWifi) {
                signalProc.running = true;
            }
        }
    }

    // Query accurate signal strength via iw
    Process {
        id: signalProc
        command: ["sh", "-c", "IFACE=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | grep ':wifi$' | head -n1 | cut -d: -f1); [ -n \"$IFACE\" ] && iw dev \"$IFACE\" link 2>/dev/null | grep signal | awk '{print $2}'"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let dbm = parseInt(text.trim());
                    if (!isNaN(dbm)) {
                        if (dbm >= -55) root.signalBars = 4;
                        else if (dbm >= -65) root.signalBars = 3;
                        else if (dbm >= -75) root.signalBars = 2;
                        else root.signalBars = 1;

                        root.signalPercent = Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))));
                    }
                }
            }
        }
    }

    // Scan nearby Wi-Fi networks (fast, no forced airwave rescan)
    Process {
        id: scanProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let lines = text.trim().split("\n");
                    let map = {};
                    let list = [];
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i];
                        let parts = line.split(":");
                        if (parts.length >= 4) {
                            let inUse = parts[0] === "*";
                            let name = parts[1].trim();
                            let sig = parseInt(parts[2]) || 0;
                            let sec = parts[3].trim();
                            if (name.length > 0) {
                                if (!map[name] || inUse || sig > map[name].signal) {
                                    map[name] = {
                                        inUse: inUse,
                                        ssid: name,
                                        signal: sig,
                                        security: sec,
                                        isSecure: sec.length > 0 && !sec.includes("--")
                                    };
                                }
                            }
                        }
                    }
                    for (let key in map) {
                        list.push(map[key]);
                    }
                    list.sort(function(a, b) {
                        if (a.inUse) return -1;
                        if (b.inUse) return 1;
                        return b.signal - a.signal;
                    });
                    root.availableNetworks = list;
                }
                root.isScanning = false;
            }
        }
    }

    // Process to toggle Wi-Fi radio on/off
    Process {
        id: toggleRadioProc
        onExited: {
            root.queryNetwork();
            if (root.isWifiEnabled) {
                root.scanWifi();
            }
        }
    }

    // Process to connect to an SSID
    Process {
        id: connectProc
        onExited: {
            root.connectingSsid = "";
            root.queryNetwork();
            root.scanWifi();
        }
    }

    // Process to launch KDE Plasma Network Settings
    Process {
        id: settingsProc
        command: ["kcmshell6", "kcm_networkmanagement"]
    }

    function queryNetwork() {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function scanWifi() {
        if (!scanProc.running && root.isWifiEnabled) {
            root.isScanning = true;
            scanProc.running = true;
        }
    }

    function toggleWifi() {
        let next = root.isWifiEnabled ? "off" : "on";
        root.isWifiEnabled = !root.isWifiEnabled;
        toggleRadioProc.command = ["nmcli", "radio", "wifi", next];
        toggleRadioProc.running = true;
    }

    function connectTo(targetSsid) {
        root.connectingSsid = targetSsid;
        connectProc.command = ["nmcli", "dev", "wifi", "connect", targetSsid];
        connectProc.running = true;
    }

    function openSettings() {
        settingsProc.running = true;
    }
}
