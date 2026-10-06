import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    readonly property real volumeStep: 0.05
    readonly property real brightnessStep: 0.05

    // IPC handler for external scripts / shortcuts
    IpcHandler {
        target: "launcher"

        function toggle() {
            DockService.toggleAppLauncherRequested();
        }
    }

    // Global controls for keyboard shortcuts. This lives here, not in IslandWindow,
    // because IslandWindow is created once per screen and IPC targets must be unique.
    // E.g.: `quickshell ipc call system volumeUp`
    IpcHandler {
        target: "system"

        function toggleDnd() {
            NotificationService.toggleDnd();
        }

        function volumeUp() {
            AudioService.setVolume(AudioService.volume + root.volumeStep);
            OsdService.show("volume");
        }

        function volumeDown() {
            AudioService.setVolume(AudioService.volume - root.volumeStep);
            OsdService.show("volume");
        }

        function toggleMute() {
            AudioService.toggleMute();
            OsdService.show("volume");
        }

        function brightnessUp() {
            BrightnessService.setBrightness(BrightnessService.brightness + root.brightnessStep);
            OsdService.show("brightness");
        }

        function brightnessDown() {
            BrightnessService.setBrightness(BrightnessService.brightness - root.brightnessStep);
            OsdService.show("brightness");
        }

        function mediaPlayPause() {
            let p = root.mediaPlayer();
            if (p) p.togglePlaying();
        }

        function mediaNext() {
            let p = root.mediaPlayer();
            if (p) p.next();
        }

        function mediaPrevious() {
            let p = root.mediaPlayer();
            if (p) p.previous();
        }
    }

    // Prefer a player that is currently playing, otherwise the first one
    function mediaPlayer() {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }

    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            IslandWindow {}
        }
    }

    // Floating Dock
    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            DockWindow {}
        }
    }
    
}
