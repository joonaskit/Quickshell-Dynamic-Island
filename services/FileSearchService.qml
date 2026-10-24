pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "launcherExtras.js" as LauncherExtras

// File search for the launcher, answered by Filehouse (`filehouse --search`, see
// its ARCHITECTURE.md under Search). One search runs at a time: a new text ends
// the one in progress, and nothing runs until the launcher asks.
Singleton {
    id: root

    // [{ path, name, folder, dir, type }], nearest to the root first
    property var results: []
    property bool searching: false
    // The search stopped at the limit
    property bool more: false
    property string error: ""
    // The text the results belong to
    property string query: ""

    readonly property int limit: 30
    // False once the check has run and did not find the command
    readonly property bool available: !DepsService.noneUsable(["filehouse"])

    // What to run once the search in progress has ended
    property string pending: ""
    property bool hasPending: false

    // delay: how long typing must pause before the walk starts
    function search(text, delay) {
        root.pending = text;
        root.hasPending = true;
        root.searching = text.length > 0 && root.available;
        debounce.interval = delay === undefined ? 250 : delay;
        debounce.restart();
    }

    function clear() {
        debounce.stop();
        root.hasPending = false;
        root.query = "";
        root.results = [];
        root.searching = false;
        root.more = false;
        root.error = "";
        if (proc.running) proc.running = false;
    }

    function start() {
        if (!root.hasPending) return;
        // Ended first; onExited comes back here
        if (proc.running) {
            proc.running = false;
            return;
        }
        root.hasPending = false;
        root.query = root.pending;
        root.results = [];
        root.more = false;
        root.error = "";
        if (root.query.length === 0 || !root.available) {
            root.searching = false;
            return;
        }
        root.searching = true;
        proc.failed = false;
        proc.command = ["filehouse", "--search", root.query, "--root", SettingsService.launcherFileSearchRoot, "--limit", String(root.limit)];
        proc.running = true;
    }

    // Typing: wait for a pause before walking the folder
    Timer {
        id: debounce
        interval: 250
        onTriggered: root.start()
    }

    Process {
        id: proc
        property bool failed: false

        stdout: SplitParser {
            onRead: function(line) {
                let item = LauncherExtras.parseFileLine(line);
                if (!item) return;
                if (item.error !== undefined) {
                    root.error = item.error;
                } else if (item.done) {
                    root.more = item.more;
                } else if (root.results.length < root.limit) {
                    root.results = root.results.concat([item]);
                }
            }
        }

        // A command that could not be started never reports an exit
        onRunningChanged: {
            if (!running && !root.hasPending) root.searching = false;
        }

        onExited: function(exitCode, exitStatus) {
            if (root.hasPending) {
                root.start();
                return;
            }
            root.searching = false;
            // An old Filehouse does not know --search and ends with a usage error
            if (exitCode === 2) root.error = "This Filehouse is too old for file search. Update it.";
        }
    }
}
