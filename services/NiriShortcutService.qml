pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// niri's keyboard shortcuts, read from and written to the binds block of its config.kdl
// by scripts/niri_binds.py. niri reloads the file by itself after each change.
Singleton {
    id: root

    // [{ name, actions: [{ id, title, detail }] }], rebuilt only when the list of actions changes
    property var groups: []
    // Action id -> list of keys such as ["Mod+Left", "Mod+H"]
    property var keysById: ({})
    // Why the last change was refused; empty when it worked
    property string error: ""
    // { id, key, title, action, oldKey, newKey } when another action has the key
    property var conflict: null
    // The config file the binds come from
    property string path: ""
    // True while a row waits for keys; the settings window then stops niri taking them
    property bool capturing: false

    property var queue: []
    property string groupSignature: ""
    property var lastSet: null

    function refresh() {
        run(["list"]);
    }

    // `oldKey` is "" to add a key to the action
    function setKey(id, oldKey, newKey) {
        lastSet = { action: id, oldKey: oldKey, newKey: newKey };
        run(["set", id, oldKey, newKey]);
    }

    // Takes the key from the action that has it
    function forceKey() {
        if (!conflict) return;
        run(["set", conflict.action, conflict.oldKey, conflict.newKey, "--force"]);
    }

    function removeKey(id, key) {
        run(["remove", id, key]);
    }

    function run(args) {
        if (proc.running) {
            // Changes must not overlap, and a pending list is redundant
            if (args[0] === "list" && queue.length > 0) return;
            queue.push(args);
            return;
        }
        proc.command = ["python3", Quickshell.shellDir + "/scripts/niri_binds.py"].concat(args);
        proc.running = true;
    }

    function apply(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            error = "Could not read niri's shortcuts";
            conflict = null;
            return;
        }
        path = data.path || "";
        error = data.error || "";
        conflict = data.conflict && lastSet ? Object.assign({}, data.conflict, lastSet) : null;

        let keys = {};
        let order = [];
        let signature = "";
        for (let g of data.groups) {
            let actions = [];
            for (let a of g.actions) {
                if (a.keys.length > 0) keys[a.id] = a.keys;
                actions.push({ id: a.id, title: a.title, detail: a.detail });
                signature += a.id + ";";
            }
            if (actions.length > 0) order.push({ name: g.name, actions: actions });
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
