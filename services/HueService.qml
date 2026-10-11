pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Philips Hue lamp control through scripts/hue.py. Does nothing until the user
// turns it on in the settings and pairs with a bridge.
Singleton {
    id: root

    readonly property bool enabled: SettingsService.hueEnabled
    readonly property bool paired: SettingsService.hueBridgeIp !== "" && SettingsService.hueAppKey !== ""

    property var lights: []
    property bool connected: false
    // Last problem reported by the script, empty when all is well
    property string error: ""

    // Pairing: "" (idle), "waiting" (asked, link button not pressed yet), "busy"
    property string pairState: ""
    property var foundBridges: []
    property bool discovering: false

    // The favourite is saved; the lamp being viewed is only remembered while the popup is open
    readonly property string favouriteId: SettingsService.hueLightId
    property string viewedId: ""

    function lightById(id) {
        for (let i = 0; i < root.lights.length; i++) {
            if (root.lights[i].id === id) return root.lights[i];
        }
        return null;
    }

    // Lamp shown in the popup: the one picked from the list, else the favourite, else the first
    readonly property var selectedLight: root.lightById(root.viewedId) || root.lightById(root.favouriteId) || (root.lights.length > 0 ? root.lights[0] : null)
    readonly property bool anyOn: root.lights.some(l => l.on)

    readonly property var env: ({
        "HUE_BRIDGE": SettingsService.hueBridgeIp,
        "HUE_KEY": SettingsService.hueAppKey
    })
    readonly property string script: Quickshell.shellDir + "/scripts/hue.py"

    function selectLight(id) {
        root.viewedId = id;
    }

    // Pins a lamp as the favourite, or unpins it when it already is
    function toggleFavourite(id) {
        SettingsService.setSetting("hueLightId", id === root.favouriteId ? "" : id);
    }

    function unpair() {
        SettingsService.setSetting("hueAppKey", "");
        root.lights = [];
        root.connected = false;
        root.error = "";
    }

    function setBridge(ip) {
        SettingsService.setSetting("hueBridgeIp", ip.trim());
    }

    property bool streamAllowed: true

    // Live state from the bridge's event stream, restarted if the connection drops
    Process {
        id: streamProc
        command: ["python3", "-u", root.script, "stream"]
        environment: root.env
        running: root.enabled && root.paired && root.streamAllowed

        onRunningChanged: {
            if (!running) {
                root.connected = false;
                if (root.enabled && root.paired) {
                    // Drop the binding's value so the timer can raise it again
                    root.streamAllowed = false;
                    restartTimer.start();
                }
            }
        }

        stdout: SplitParser {
            onRead: function(line) {
                try {
                    let msg = JSON.parse(line);
                    if (msg.lights) {
                        root.lights = msg.lights;
                        root.connected = true;
                        root.error = "";
                    } else if (msg.error) {
                        root.error = msg.error;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        onTriggered: root.streamAllowed = true
    }

    // Slider writes go out at most every 80 ms so dragging does not flood the bridge
    property var pending: ({})

    function applyLocal(id, changes) {
        root.lights = root.lights.map(l => l.id === id ? Object.assign({}, l, changes) : l);
    }

    function queue(id, changes) {
        root.applyLocal(id, changes);
        root.pending[id] = Object.assign(root.pending[id] || {}, changes);
        flushTimer.restart();
    }

    Timer {
        id: flushTimer
        interval: 80
        onTriggered: {
            for (let id in root.pending) {
                let c = root.pending[id];
                let args = ["set", id, "--on"];
                if (c.brightness !== undefined) args.push("--brightness", String(c.brightness));
                if (c.mirek !== undefined) args.push("--mirek", String(c.mirek));
                root.run(args);
            }
            root.pending = {};
        }
    }

    // One-shot helper call; the script prints {"error": ...} when something goes wrong
    Component {
        id: runner
        Process {
            environment: root.env
            stdout: SplitParser {
                onRead: function(line) {
                    try {
                        let msg = JSON.parse(line);
                        if (msg.error) root.error = msg.error;
                    } catch (e) {}
                }
            }
            onExited: destroy(100)
        }
    }

    function run(args) {
        runner.createObject(root, { "command": ["python3", root.script].concat(args), "running": true });
    }

    function setOn(id, on) {
        delete root.pending[id];
        root.applyLocal(id, { "on": on });
        root.run(["set", id, on ? "--on" : "--off"]);
    }

    function toggle(id) {
        for (let i = 0; i < root.lights.length; i++) {
            if (root.lights[i].id === id) {
                root.setOn(id, !root.lights[i].on);
                return;
            }
        }
    }

    // percent is 0-100; moving the slider also turns the lamp on
    function setBrightness(id, percent) {
        let value = Math.max(1, Math.min(100, Math.round(percent)));
        root.queue(id, { "brightness": value, "on": true });
    }

    function setMirek(id, mirek) {
        let value = Math.round(mirek);
        root.queue(id, { "mirek": value, "on": true });
    }

    function discover() {
        if (discoverProc.running) return;
        root.discovering = true;
        root.foundBridges = [];
        discoverProc.running = true;
    }

    Process {
        id: discoverProc
        command: ["python3", root.script, "discover"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.discovering = false;
                try {
                    let msg = JSON.parse(text.trim());
                    if (msg.bridges) {
                        root.foundBridges = msg.bridges;
                        if (msg.bridges.length > 0 && SettingsService.hueBridgeIp === "") {
                            root.setBridge(msg.bridges[0]);
                        }
                    } else if (msg.error) {
                        root.error = msg.error;
                    }
                } catch (e) {
                    root.error = "could not look for bridges";
                }
            }
        }
    }

    // The user presses the bridge's link button, then asks to pair
    function pair() {
        if (pairProc.running || SettingsService.hueBridgeIp === "") return;
        root.error = "";
        root.pairState = "busy";
        pairProc.running = true;
    }

    Process {
        id: pairProc
        command: ["python3", root.script, "pair"]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let msg = JSON.parse(text.trim());
                    if (msg.key) {
                        root.pairState = "";
                        SettingsService.setSetting("hueAppKey", msg.key);
                    } else if (msg.error === "link_button") {
                        root.pairState = "waiting";
                    } else {
                        root.pairState = "";
                        root.error = msg.error || "pairing failed";
                    }
                } catch (e) {
                    root.pairState = "";
                    root.error = "could not reach the bridge";
                }
            }
        }
    }
}
