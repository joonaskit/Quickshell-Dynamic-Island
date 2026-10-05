pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real volume: 0.5
    property bool isMuted: false
    property bool isChanging: false

    property string pendingVolume: ""
    property bool pendingMuteToggle: false

    // Audio Output Sinks
    property var sinks: []
    property var currentSink: null
    property string currentSinkName: ""
    property string currentSinkDisplayName: "Default Audio"
    property string currentSinkIcon: "volume-high"

    // Polling timer to catch keyboard volume buttons / quick keys
    Timer {
        id: pollTimer
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!root.isChanging) {
                root.queryVolume();
            }
        }
    }

    // Periodic timer to detect audio device changes (headphones plugged in, bluetooth connected)
    Timer {
        id: sinksTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            root.querySinks();
        }
    }

    // Process to query current volume
    Process {
        id: queryProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onTextChanged: {
                if (root.isChanging) return;
                if (text.length > 0) {
                    let t = text.trim();
                    let parts = t.split(/\s+/);
                    if (parts.length >= 2) {
                        let v = parseFloat(parts[1]);
                        if (!isNaN(v)) {
                            root.volume = Math.min(1.0, Math.max(0.0, v));
                        }
                    }
                    root.isMuted = t.includes("[MUTED]");
                }
            }
        }
    }

    // Process to query audio output sinks
    Process {
        id: sinksProc
        command: ["python3", Quickshell.shellDir + "/scripts/audio_sinks.py", "list"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    try {
                        let list = JSON.parse(text.trim());
                        root.sinks = list;
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].isDefault) {
                                root.currentSink = list[i];
                                root.currentSinkName = list[i].name;
                                root.currentSinkDisplayName = list[i].displayName;
                                root.currentSinkIcon = list[i].icon;
                                break;
                            }
                        }
                    } catch(e) {}
                }
            }
        }
    }

    // Process to set volume or toggle mute with queueing
    Process {
        id: setProc
        onExited: {
            if (root.pendingVolume !== "") {
                let next = root.pendingVolume;
                root.pendingVolume = "";
                command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", next];
                running = true;
            } else if (root.pendingMuteToggle) {
                root.pendingMuteToggle = false;
                command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
                running = true;
            }
        }
    }

    // Process to set default sink
    Process {
        id: setSinkProc
        onExited: {
            root.queryVolume();
            root.querySinks();
        }
    }

    function queryVolume() {
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    function querySinks() {
        if (!sinksProc.running) {
            sinksProc.running = true;
        }
    }

    function setDefaultSink(sinkName) {
        if (!sinkName) return;
        for (let i = 0; i < root.sinks.length; i++) {
            root.sinks[i].isDefault = (root.sinks[i].name === sinkName);
            if (root.sinks[i].name === sinkName) {
                root.currentSink = root.sinks[i];
                root.currentSinkName = root.sinks[i].name;
                root.currentSinkDisplayName = root.sinks[i].displayName;
                root.currentSinkIcon = root.sinks[i].icon;
            }
        }
        setSinkProc.command = ["python3", Quickshell.shellDir + "/scripts/audio_sinks.py", "set", sinkName];
        setSinkProc.running = true;
    }

    function setVolume(val) {
        root.volume = Math.min(1.0, Math.max(0.0, val));
        if (root.isMuted && root.volume > 0.01) {
            root.isMuted = false;
        }
        let pct = Math.round(root.volume * 100) + "%";
        if (setProc.running) {
            root.pendingVolume = pct;
        } else {
            setProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct];
            setProc.running = true;
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        if (setProc.running) {
            root.pendingMuteToggle = true;
        } else {
            setProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
            setProc.running = true;
        }
    }

    Component.onCompleted: {
        root.queryVolume();
        root.querySinks();
    }
}
