pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real brightness: 0.65
    property bool isAvailable: false
    property bool isChanging: false
    property string pendingBrightness: ""

    // Polling timer to catch hardware Fn brightness keys (only active if brightness is supported)
    Timer {
        id: pollTimer
        interval: 600
        running: root.isAvailable
        repeat: true
        onTriggered: {
            if (!root.isChanging) {
                root.queryBrightness();
            }
        }
    }

    // Process to safely verify brightnessctl and backlight support on startup
    Process {
        id: checkProc
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m 2>/dev/null"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let t = text.trim();
                    let parts = t.split(",");
                    if (parts.length >= 4) {
                        let pct = parseFloat(parts[3]);
                        if (!isNaN(pct)) {
                            root.brightness = Math.min(1.0, Math.max(0.01, pct / 100.0));
                            root.isAvailable = true;
                        }
                    }
                }
            }
        }
    }

    // Process to query current brightness
    Process {
        id: queryProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onTextChanged: {
                if (root.isChanging) return;
                if (text.length > 0) {
                    let t = text.trim();
                    let parts = t.split(",");
                    if (parts.length >= 4) {
                        let pct = parseFloat(parts[3]);
                        if (!isNaN(pct)) {
                            root.brightness = Math.min(1.0, Math.max(0.01, pct / 100.0));
                        }
                    }
                }
            }
        }
    }

    // Process to set brightness with queueing
    Process {
        id: setProc
        onExited: {
            if (root.pendingBrightness !== "") {
                let next = root.pendingBrightness;
                root.pendingBrightness = "";
                command = ["brightnessctl", "set", next];
                running = true;
            }
        }
    }

    function checkAvailability() {
        if (!checkProc.running) {
            checkProc.running = true;
        }
    }

    function queryBrightness() {
        if (root.isAvailable && !queryProc.running) {
            queryProc.running = true;
        }
    }

    function setBrightness(val) {
        if (!root.isAvailable) return;
        root.brightness = Math.min(1.0, Math.max(0.01, val));
        let pct = Math.max(1, Math.round(root.brightness * 100)) + "%";
        if (setProc.running) {
            root.pendingBrightness = pct;
        } else {
            setProc.command = ["brightnessctl", "set", pct];
            setProc.running = true;
        }
    }

    Component.onCompleted: checkAvailability()
}
