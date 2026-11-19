pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Feral GameMode through scripts/gamemode.py. Does nothing until the widget is
// turned on in the settings. "Forcing" registers the shell itself with gamemoded
// so its optimisations (CPU governor, process priority, ...) apply without a
// game started through gamemoderun. gamemoded drops the registration when the
// shell exits, so nothing is left behind.
Singleton {
    id: root

    readonly property bool enabled: SettingsService.gameModeEnabled
    readonly property string script: Quickshell.shellDir + "/scripts/gamemode.py"

    // False while gamemoded cannot be reached (not installed)
    property bool available: true
    // Games registered by other processes: [{pid, name}]
    property var games: []
    // Whether the shell has registered itself
    property bool forced: false
    readonly property bool active: root.forced || root.games.length > 0

    function refresh() {
        if (!statusProc.running) statusProc.running = true;
    }

    function setForced(on) {
        // Optimistic, so the switch moves at once; the status read after it corrects it
        root.forced = on;
        runProc.command = ["python3", root.script, on ? "force-on" : "force-off"];
        runProc.running = true;
    }

    function applyStatus(line) {
        try {
            let msg = JSON.parse(line.trim());
            root.available = !!msg.available;
            root.games = msg.games || [];
            root.forced = !!msg.forced;
            return;
        } catch (e) {}
        root.available = false;
        root.games = [];
        root.forced = false;
    }

    // Prints the status again whenever gamemoded signals a change
    HelperProcess {
        helperId: "gamemode"
        helperName: "GameMode watcher"
        wanted: root.enabled
        command: ["python3", "-u", root.script, "watch"]
        stdout: SplitParser {
            onRead: line => root.applyStatus(line)
        }
    }

    // A one-off read, for when the popup opens and after a change made here
    Process {
        id: statusProc
        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Process {
        id: runProc
        onExited: root.refresh()
    }
}
