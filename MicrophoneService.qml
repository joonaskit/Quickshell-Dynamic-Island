pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isMuted: false
    property real volume: 1.0
    property string defaultSource: "Microphone"
    property var sources: []

    // Process to query input volume and mute status via wpctl/pactl
    Process {
        id: statusProc
        command: ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SOURCE@; else LC_ALL=C pactl get-source-mute @DEFAULT_SOURCE@; LC_ALL=C pactl get-source-volume @DEFAULT_SOURCE@; fi"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    let t = text.trim();
                    if (t.includes("[MUTED]")) {
                        root.isMuted = true;
                    } else if (t.toLowerCase().includes("mute: yes") || t.toLowerCase().includes("mute: kyllä")) {
                        root.isMuted = true;
                    } else if (t.toLowerCase().includes("mute: no") || t.toLowerCase().includes("mute: ei")) {
                        root.isMuted = false;
                    } else if (t.includes("Volume:")) {
                        root.isMuted = false;
                    }

                    let parts = t.split(/\s+/);
                    if (parts.length >= 2 && !isNaN(parseFloat(parts[1]))) {
                        root.volume = Math.min(1.0, Math.max(0.0, parseFloat(parts[1])));
                    } else {
                        let match = t.match(/(\d+)%/);
                        if (match) {
                            root.volume = Math.max(0.0, Math.min(1.0, parseInt(match[1]) / 100.0));
                        }
                    }
                }
            }
        }
    }

    // Process to query audio sources list
    Process {
        id: sourcesProc
        command: ["python3", Quickshell.shellDir + "/audio_sources.py", "list"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                let t = text.trim();
                if (t.length > 0) {
                    try {
                        let list = JSON.parse(t);
                        root.sources = list;
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].isDefault) {
                                root.defaultSource = list[i].displayName;
                                break;
                            }
                        }
                    } catch(e) {}
                }
            }
        }
    }

    // Fast polling timer to catch hardware keys and desktop shortcut mutes immediately
    Timer {
        id: pollTimer
        interval: 350
        running: true
        repeat: true
        onTriggered: {
            root.queryStatus();
        }
    }

    Component.onCompleted: {
        root.queryStatus();
        root.querySources();
    }

    function queryStatus() {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function querySources() {
        if (!sourcesProc.running) {
            sourcesProc.running = true;
        }
    }

    Process {
        id: setMuteProc
        running: false
        onExited: {
            refreshTimer.restart();
        }
    }

    Process {
        id: setVolumeProc
        running: false
    }

    Process {
        id: setSourceProc
        running: false
        onExited: {
            refreshTimer.restart();
        }
    }

    function toggleMute() {
        root.isMuted = !root.isMuted;
        setMuteProc.command = ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle; else pactl set-source-mute @DEFAULT_SOURCE@ toggle; fi"];
        setMuteProc.running = true;
        refreshTimer.restart();
    }

    function setMute(muted) {
        root.isMuted = muted;
        let arg = muted ? "1" : "0";
        setMuteProc.command = ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl set-mute @DEFAULT_AUDIO_SOURCE@ " + arg + "; else pactl set-source-mute @DEFAULT_SOURCE@ " + arg + "; fi"];
        setMuteProc.running = true;
        refreshTimer.restart();
    }

    function setVolume(val) {
        let clamped = Math.max(0.0, Math.min(1.0, val));
        root.volume = clamped;
        let pct = Math.round(clamped * 100);
        setVolumeProc.command = ["sh", "-c", "if command -v wpctl >/dev/null 2>&1; then wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + clamped.toFixed(2) + "; else pactl set-source-volume @DEFAULT_SOURCE@ " + pct + "%; fi"];
        setVolumeProc.running = true;
    }

    function setSource(sourceName) {
        setSourceProc.command = ["python3", Quickshell.shellDir + "/audio_sources.py", "set", sourceName];
        setSourceProc.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.queryStatus();
            root.querySources();
        }
    }
}
