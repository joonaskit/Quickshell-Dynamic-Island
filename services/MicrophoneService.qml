pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "audioDevices.js" as AudioDevices

Singleton {
    id: root

    // The default input. PipeWire reports mute and volume changes as they happen
    // (hardware mute keys, desktop shortcuts), so nothing is polled
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool isMuted: root.source && root.source.audio ? root.source.audio.muted : false
    readonly property real volume: root.source && root.source.audio ? Math.min(1.0, root.source.audio.volume) : 1.0
    readonly property string defaultSource: root.source ? AudioDevices.sourceDisplayName(root.source) : "Microphone"
    readonly property var sources: {
        let nodes = Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource);
        return AudioDevices.deviceList(nodes, root.source, AudioDevices.sourceDisplayName);
    }

    // Binds the source so its audio properties (volume, muted) are available
    PwObjectTracker {
        objects: [root.source]
    }

    function toggleMute() {
        if (!root.source || !root.source.audio) return;
        root.source.audio.muted = !root.source.audio.muted;
    }

    function setMute(muted) {
        if (!root.source || !root.source.audio) return;
        root.source.audio.muted = muted;
    }

    function setVolume(val) {
        if (!root.source || !root.source.audio) return;
        root.source.audio.volume = Math.max(0.0, Math.min(1.0, val));
    }

    function setSource(sourceName) {
        let node = Pipewire.nodes.values.find(n => n.type === PwNodeType.AudioSource && n.name === sourceName);
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }
}
