pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isConnected: false
    property bool isWifi: false
    property bool isWifiEnabled: true
    property string ssid: ""
    property var availableNetworks: []
    property bool isScanning: false
    property string connectingSsid: ""
    // Names of the saved Wi-Fi connections, which NetworkManager names after the SSID
    property var savedSsids: []
    // The network the last connect failed on, until the next connect
    property string failedSsid: ""
    // Password for the connect in progress, written to nmcli's prompt once it starts
    property string pendingPassword: ""

    // nmcli monitor prints a line whenever NetworkManager's state changes (a connection
    // coming up or going down, the Wi-Fi radio switched), so the status is read again
    // only then. A burst of lines is read once
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        running: true

        Component.onCompleted: HelperService.watch("network", "Network monitor", monitorProc)

        onRunningChanged: {
            if (!running) {
                restartTimer.start();
            }
        }

        stdout: SplitParser {
            onRead: function(line) {
                queryDelay.restart();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: {
            if (!monitorProc.running) {
                monitorProc.running = true;
            }
        }
    }

    Timer {
        id: queryDelay
        interval: 300
        onTriggered: root.queryNetwork()
    }

    Component.onCompleted: root.queryNetwork()

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

    // Saved Wi-Fi connections. nmcli -t escapes a colon in a name as "\:"; the type is last.
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                let names = [];
                text.trim().split("\n").forEach(line => {
                    let cut = line.lastIndexOf(":");
                    if (cut > 0 && line.slice(cut + 1) === "802-11-wireless")
                        names.push(line.slice(0, cut).replace(/\\:/g, ":").replace(/\\\\/g, "\\"));
                });
                root.savedSsids = names;
            }
        }
    }

    // Process to connect to an SSID. With a password, nmcli --ask prompts for it on stdin,
    // so it never shows in the process list.
    Process {
        id: connectProc
        stdinEnabled: true
        onStarted: {
            if (root.pendingPassword !== "") {
                connectProc.write(root.pendingPassword + "\n");
                root.pendingPassword = "";
            }
        }
        onExited: function(exitCode) {
            root.pendingPassword = "";
            if (exitCode !== 0) root.failedSsid = root.connectingSsid;
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
        if (!savedProc.running) savedProc.running = true;
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

    function isSaved(targetSsid) {
        return root.savedSsids.indexOf(targetSsid) >= 0;
    }

    // Connects to a network, with `password` for one that is not saved yet
    function connectTo(targetSsid, password) {
        if (connectProc.running) return;
        root.connectingSsid = targetSsid;
        root.failedSsid = "";
        root.pendingPassword = password || "";
        connectProc.command = password
            ? ["nmcli", "--ask", "dev", "wifi", "connect", targetSsid]
            : ["nmcli", "dev", "wifi", "connect", targetSsid];
        connectProc.running = true;
    }

    function openSettings() {
        settingsProc.running = true;
    }
}
