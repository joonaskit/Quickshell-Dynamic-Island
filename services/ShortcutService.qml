pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Global keyboard shortcuts for the shell's IPC commands. They are stored in KDE's
// own shortcut settings; scripts/shortcuts.py does the reading and writing.
Singleton {
    id: root

    // [{ name, actions: [{ id, title, command }] }], rebuilt only when the list of actions changes
    property var groups: []
    // Action id -> shortcut text such as "Meta+V" (missing when unbound)
    property var keysById: ({})
    // Why the last change was refused; empty when it worked
    property string error: ""

    property var queue: []
    property string groupSignature: ""

    function refresh() {
        run(["list"]);
    }

    // `code` is Qt's key code: the key plus the modifier bits
    function setShortcut(id, code) {
        run(["set", id, String(code)]);
    }

    function clearShortcut(id) {
        run(["clear", id]);
    }

    function run(args) {
        if (proc.running) {
            // Changes must not overlap, and a pending list is redundant
            if (args[0] === "list" && queue.length > 0) return;
            queue.push(args);
            return;
        }
        proc.command = ["python3", Quickshell.shellDir + "/scripts/shortcuts.py"].concat(args);
        proc.running = true;
    }

    function apply(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            error = "Could not read the shortcuts from KDE";
            return;
        }
        error = data.error || "";

        let keys = {};
        let order = [];
        let byName = {};
        let signature = "";
        for (let a of data.actions) {
            if (a.keys !== "") keys[a.id] = a.keys;
            if (!byName[a.group]) {
                byName[a.group] = { name: a.group, actions: [] };
                order.push(byName[a.group]);
            }
            byName[a.group].actions.push({ id: a.id, title: a.title, command: a.command });
            signature += a.id + ";";
        }
        keysById = keys;
        if (signature !== groupSignature) {
            groupSignature = signature;
            groups = order;
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                root.apply(text);
                if (root.queue.length > 0) root.run(root.queue.shift());
            }
        }
    }
}
