pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "themeExport.js" as ThemeExport

// Writes the shell's theme to a file that companion apps read, and rewrites it
// when the theme or the scale settings change. Format and location: docs/THEME.md
Singleton {
    id: root

    readonly property string themeJson: JSON.stringify(ThemeExport.build({
        "background": String(Theme.islandBackground),
        "surface": String(Theme.cardBackground),
        "surfaceRaised": String(Theme.cardBackgroundHover),
        "textPrimary": String(Theme.textPrimary),
        "textSecondary": String(Theme.textSecondary),
        "textTertiary": String(Theme.textTertiary),
        "onAccent": String(Theme.onAccent),
        "accentGreen": String(Theme.accentGreen),
        "accentBlue": String(Theme.accentBlue),
        "accentOrange": String(Theme.accentOrange),
        "accentYellow": String(Theme.accentYellow),
        "accentRed": String(Theme.accentRed),
        "accentPurple": String(Theme.accentPurple),
        "accentCyan": String(Theme.accentCyan),
        "accentIndigo": String(Theme.accentIndigo),
        "fontFamily": Theme.fontFamily,
        "fontDisplay": Theme.fontDisplay,
        "radiusSmall": Theme.radiusSmall,
        "radiusMedium": Theme.radiusMedium,
        "radiusLarge": Theme.radiusLarge,
        "uiScale": Theme.uiScale,
        "fontScale": Theme.fontScale
    }))

    onThemeJsonChanged: writeTimer.restart()

    // Debounced so dragging a scale slider, or settings loading at startup,
    // results in one write
    Timer {
        id: writeTimer
        interval: 500
        repeat: false
        onTriggered: root.writeTheme()
    }

    Process {
        id: writeProc
        command: []
    }

    function writeTheme() {
        if (writeProc.running) {
            writeTimer.restart();
            return;
        }
        writeProc.command = ["python3", Quickshell.shellDir + "/scripts/write_theme.py", root.themeJson];
        writeProc.running = true;
    }

    Component.onCompleted: writeTimer.restart()
}
