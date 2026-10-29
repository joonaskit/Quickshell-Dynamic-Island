pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "audioDevices.js" as AudioDevices

Singleton {
    id: root

    // The default output. PipeWire reports volume, mute and device changes as they
    // happen (volume keys, headphones plugged in), so nothing is polled
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: root.sink && root.sink.audio ? Math.min(1.0, root.sink.audio.volume) : 0
    readonly property bool isMuted: root.sink && root.sink.audio ? root.sink.audio.muted : false

    // Audio Output Sinks
    readonly property var sinks: {
        let nodes = Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink);
        return AudioDevices.deviceList(nodes, root.sink, AudioDevices.sinkDisplayName);
    }
    readonly property string currentSinkDisplayName: root.sink ? AudioDevices.sinkDisplayName(root.sink) : "Default Audio"
    readonly property string currentSinkIcon: root.sink ? AudioDevices.sinkIcon(root.sink) : "volume-high"

    // Binds the sink so its audio properties (volume, muted) are available
    PwObjectTracker {
        objects: [root.sink]
    }

    function setDefaultSink(sinkName) {
        let node = Pipewire.nodes.values.find(n => n.type === PwNodeType.AudioSink && n.name === sinkName);
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolume(val) {
        if (!root.sink || !root.sink.audio) return;
        let v = Math.min(1.0, Math.max(0.0, val));
        root.sink.audio.volume = v;
        if (root.sink.audio.muted && v > 0.01) root.sink.audio.muted = false;
    }

    function toggleMute() {
        if (!root.sink || !root.sink.audio) return;
        root.sink.audio.muted = !root.sink.audio.muted;
    }
}
