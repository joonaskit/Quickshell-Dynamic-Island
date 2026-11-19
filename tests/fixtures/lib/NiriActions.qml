import QtQuick
import Quickshell.Io

// The actions a fixture sent to tests/fake_niri.py, read from its log ($FAKE_NIRI_LOG)
// on each call to has(), and a way to make it drop the event stream.
Item {
    id: root

    property var lines: []

    // True once the log has an action whose JSON is `json` (as niri's IPC spells it,
    // without spaces). Re-reads the log while waiting.
    function has(json) {
        if (!reader.running) reader.running = true;
        return root.lines.indexOf(json) >= 0;
    }

    // Closes the event streams, as when niri restarts
    function dropStreams() {
        dropper.running = true;
    }

    Process {
        id: reader
        command: ["sh", "-c", "cat \"$FAKE_NIRI_LOG\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.lines = this.text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: dropper
        command: ["sh", "-c", "kill -USR1 \"$FAKE_NIRI_PID\""]
    }
}
