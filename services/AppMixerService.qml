pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Playback streams (apps currently connected to an audio output)
    readonly property var streams: {
        let nodes = Pipewire.nodes.values;
        let result = [];
        for (let i = 0; i < nodes.length; i++) {
            let n = nodes[i];
            // Playback streams report isSink = true. Don't test n.audio here: it is only
            // populated once the node is tracked below.
            if (n.isStream && n.isSink) result.push(n);
        }
        return result;
    }

    // Binds the streams so their audio properties (volume, muted) are available
    PwObjectTracker {
        objects: root.streams
    }

    function displayName(node) {
        let p = node.properties || {};
        return p["application.name"] || node.description || node.nickname || node.name || "Unknown";
    }

    function iconFor(node) {
        let p = node.properties || {};
        return p["application.icon-name"] || p["application.process.binary"] || (p["application.name"] || "").toLowerCase();
    }

    function setVolume(node, val) {
        if (!node || !node.audio) return;
        node.audio.volume = Math.max(0, Math.min(1.0, val));
        if (node.audio.muted && val > 0.01) node.audio.muted = false;
    }

    function toggleMute(node) {
        if (!node || !node.audio) return;
        node.audio.muted = !node.audio.muted;
    }
}
