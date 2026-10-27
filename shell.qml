import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    readonly property real volumeStep: 0.05
    readonly property real brightnessStep: 0.05

    // Singletons are created on first use; nothing else references these
    readonly property var themeExport: ThemeExportService
    readonly property var kdeTheme: KdeThemeService
    readonly property var kioJobs: KioJobsService

    // IPC handler for external scripts / shortcuts
    IpcHandler {
        target: "launcher"

        function toggle() {
            DockService.toggleAppLauncherRequested();
        }

        // Open the launcher directly on the open-windows tab
        function windows() {
            DockService.windowSwitcherRequested();
        }
    }

    IpcHandler {
        target: "onboarding"

        // Show the welcome guide again
        function open() {
            OnboardingService.show();
        }
    }

    IpcHandler {
        target: "config"

        // Re-read the config files from disk, after scripts/settings_backup.py has imported them
        function reload() {
            BackupService.reloadConfig();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            ClipboardService.toggleWindow();
        }

        function toggleIncognito() {
            ClipboardService.incognito = !ClipboardService.incognito;
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

        function startTimer(minutes: int) {
            TimerService.startTimer(minutes * 60000);
        }

        function toggleTimer() {
            TimerService.toggleTimer();
        }

        function cancelTimer() {
            TimerService.resetTimer();
        }

        function toggleStopwatch() {
            TimerService.toggleStopwatch();
        }

        function resetStopwatch() {
            TimerService.resetStopwatch();
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
        model: ScreenService.targetScreens

        delegate: Component {
            IslandWindow {}
        }
    }

    // Welcome guide, on the main screen only
    OnboardingWindow {}

    // Clipboard history
    Variants {
        model: ScreenService.targetScreens

        delegate: Component {
            ClipboardWindow {}
        }
    }

    // Settings
    Variants {
        model: ScreenService.targetScreens

        delegate: Component {
            SettingsWindow {}
        }
    }

    // Floating Dock
    Variants {
        model: ScreenService.targetScreens

        delegate: Component {
            DockWindow {}
        }
    }

    // Centred launcher, used while the dock is hidden
    Variants {
        model: ScreenService.targetScreens

        delegate: Component {
            SpotlightWindow {}
        }
    }
    
}
