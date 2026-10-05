pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string currentText: ""
    property var history: []
    property bool isAvailable: true
    readonly property int maxHistory: 15

    // Periodic poll to catch clipboard changes from any application
    Timer {
        id: pollTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            root.queryClipboard();
        }
    }

    // Process to read current clipboard
    Process {
        id: queryProc
        command: ["sh", "-c", "command -v wl-paste >/dev/null 2>&1 && wl-paste -n 2>/dev/null || true"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text !== undefined) {
                    root.handleNewClipboardText(text);
                }
            }
        }
    }

    // Process to clear clipboard
    Process {
        id: clearProc
        command: ["sh", "-c", "wl-copy -c 2>/dev/null; wl-copy -c -p 2>/dev/null || true"]
    }

    // Process to set clipboard
    Process {
        id: copyProc
    }

    function queryClipboard() {
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    function handleNewClipboardText(newText) {
        if (newText === root.currentText) return;
        root.currentText = newText;

        if (newText.trim().length === 0) {
            return;
        }

        // Add or bring to top of history
        let list = (root.history || []).slice();
        let idx = list.indexOf(newText);
        if (idx !== -1) {
            list.splice(idx, 1);
        }
        list.unshift(newText);
        if (list.length > root.maxHistory) {
            list = list.slice(0, root.maxHistory);
        }
        root.history = list;
    }

    function copyText(val) {
        if (val === undefined || val === null) return;
        root.currentText = val;

        let list = (root.history || []).slice();
        let idx = list.indexOf(val);
        if (idx !== -1) {
            list.splice(idx, 1);
        }
        list.unshift(val);
        root.history = list;

        copyProc.command = ["wl-copy", val];
        copyProc.running = true;
    }

    function clearClipboard() {
        root.currentText = "";
        root.history = [];
        if (!clearProc.running) {
            clearProc.running = true;
        }
    }

    function removeItem(index) {
        let list = (root.history || []).slice();
        if (index >= 0 && index < list.length) {
            let removed = list.splice(index, 1)[0];
            root.history = list;
            if (removed === root.currentText) {
                if (list.length > 0) {
                    root.copyText(list[0]);
                } else {
                    root.clearClipboard();
                }
            }
        }
    }

    Component.onCompleted: queryClipboard()
}
