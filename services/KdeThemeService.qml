pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Applies the shell's colours to KDE as a colour scheme while the kdeColorScheme
// setting is on, and restores the scheme from before when it is turned off.
// scripts/kde_colors.py builds the scheme and keeps the scheme from before. See docs/KDE_THEME.md
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/kde_colors.py"
    readonly property bool enabled: SettingsService.kdeColorScheme
    // The light scheme is always built on its surface, as Filehouse does
    readonly property string base: Theme.isLight ? "gray" : SettingsService.kdeColorBase
    // Waits for settings.json, so the defaults never restore a scheme the user has on
    readonly property bool ready: SettingsService.isLoaded

    // Only the colours and the base: a scale, font or corner change also rewrites theme.json but leaves KDE alone
    readonly property string colorsKey: {
        try {
            let theme = JSON.parse(ThemeExportService.themeJson);
            return JSON.stringify([theme.scheme, theme.colors, root.base]);
        } catch (e) {
            return "";
        }
    }

    // Why the last apply or restore failed, for the settings page; empty when it worked
    property string error: ""
    readonly property bool busy: proc.running
    property bool pending: false

    onEnabledChanged: syncTimer.restart()
    onReadyChanged: syncTimer.restart()
    onColorsKeyChanged: {
        if (root.enabled) syncTimer.restart();
    }

    // Longer than the theme.json write: applying a scheme repaints every open KDE app
    Timer {
        id: syncTimer
        interval: 1500
        repeat: false
        onTriggered: root.sync()
    }

    function sync() {
        if (!root.ready) return;
        if (proc.running) {
            root.pending = true;
            return;
        }
        root.pending = false;
        proc.command = root.enabled
            ? ["python3", root.script, "apply", ThemeExportService.themeJson, root.base]
            : ["python3", root.script, "restore"];
        proc.running = true;
    }

    Process {
        id: proc
        command: []

        stderr: StdioCollector {
            id: errCollector
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let result = text.trim();
                if (result === "") {
                    let message = errCollector.text.trim().replace(/^kde_colors\.py: /, "");
                    root.error = message !== "" ? message : "The colour scheme could not be applied";
                    console.warn("[KdeThemeService] " + root.error);
                } else {
                    root.error = "";
                    // The user picked another scheme in System Settings, so the shell stops applying its own
                    if (result === "overridden") SettingsService.setSetting("kdeColorScheme", false);
                }
                if (root.pending) syncTimer.restart();
            }
        }
    }
}
