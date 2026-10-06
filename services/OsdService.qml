pragma Singleton
import ".."
import QtQuick
import Quickshell

Singleton {
    id: root

    // "volume" or "brightness"
    property string kind: "volume"
    property bool isShowing: false

    readonly property bool isMuted: root.kind === "volume" && AudioService.isMuted
    readonly property real value: root.kind === "volume"
        ? (AudioService.isMuted ? 0 : AudioService.volume)
        : BrightnessService.brightness
    readonly property string iconName: {
        if (root.kind === "brightness") return root.value > 0.5 ? "brightness-high" : "brightness-low";
        if (root.isMuted || root.value <= 0.01) return "volume-mute";
        return root.value < 0.4 ? "volume-low" : "volume-high";
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.isShowing = false
    }

    // Called for changes made through IPC shortcuts. Plasma shows its own OSD for
    // hardware keys and the sliders show their own value, so neither triggers this.
    function show(kind) {
        if (!SettingsService.showOsd) return;
        root.kind = kind;
        root.isShowing = true;
        hideTimer.restart();
    }
}
