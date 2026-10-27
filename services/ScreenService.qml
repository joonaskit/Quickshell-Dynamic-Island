pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Decides which screens get the island, dock and the other windows (screenMode setting).
Singleton {
    id: root

    // Name of the main display in KDE System Settings, empty when it is not known
    property string primaryName: ""

    readonly property var screens: Quickshell.screens

    // The screen KDE marks as main, else the first one
    readonly property var primaryScreen: {
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === primaryName) return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // The screens the shell is shown on. A named screen that is not connected falls back to the main one.
    readonly property var targetScreens: {
        if (SettingsService.screenMode === "all") return screens;
        if (SettingsService.screenMode === "named") {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === SettingsService.screenName) return [screens[i]];
            }
        }
        return primaryScreen ? [primaryScreen] : [];
    }

    function refresh() {
        if (!primaryProc.running) primaryProc.running = true;
    }

    Component.onCompleted: refresh()

    // Screens plugged in or out, or arranged again
    Connections {
        target: Quickshell
        function onScreensChanged() { root.refresh(); }
    }

    // KDE gives the main display priority 1
    Process {
        id: primaryProc
        command: ["kscreen-doctor", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try {
                    let outputs = JSON.parse(text).outputs || [];
                    for (let i = 0; i < outputs.length; i++) {
                        if (outputs[i].enabled && outputs[i].priority === 1) name = outputs[i].name;
                    }
                } catch (e) {}
                root.primaryName = name;
            }
        }
    }
}
