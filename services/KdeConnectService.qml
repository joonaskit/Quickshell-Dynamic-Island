pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// KDE Connect through scripts/kdeconnect.py. Does nothing until the widget is
// turned on in the settings.
Singleton {
    id: root

    readonly property bool enabled: SettingsService.kdeConnectEnabled
    readonly property string script: Quickshell.shellDir + "/scripts/kdeconnect.py"

    // Paired devices as listed by the script
    property var devices: []
    // False while the daemon cannot be reached (not installed or not running)
    property bool daemonAvailable: true
    // Short feedback for the last action, cleared after a moment
    property string notice: ""
    property bool noticeIsError: false

    // The device shown: the one picked, else the first that is reachable, else the first
    readonly property var device: {
        for (let i = 0; i < root.devices.length; i++) {
            if (root.devices[i].id === SettingsService.kdeConnectDeviceId) return root.devices[i];
        }
        for (let j = 0; j < root.devices.length; j++) {
            if (root.devices[j].reachable) return root.devices[j];
        }
        return root.devices.length > 0 ? root.devices[0] : null;
    }
    readonly property bool anyReachable: root.devices.some(d => d.reachable)

    function selectDevice(id) {
        SettingsService.setSetting("kdeConnectDeviceId", id);
    }

    function refresh() {
        if (!listProc.running) listProc.running = true;
    }

    Timer {
        interval: 5000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        command: ["python3", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let msg = JSON.parse(text.trim());
                    if (msg.devices) {
                        root.devices = msg.devices;
                        root.daemonAvailable = true;
                        return;
                    }
                } catch (e) {}
                root.daemonAvailable = false;
                root.devices = [];
            }
        }
    }

    function showNotice(message, isError) {
        root.notice = message;
        root.noticeIsError = !!isError;
        noticeTimer.restart();
    }

    Timer {
        id: noticeTimer
        interval: 2500
        onTriggered: root.notice = ""
    }

    // One-shot script call; the script prints {"error": ...} when something goes wrong
    Component {
        id: runner
        Process {
            id: proc
            property string okMessage: ""
            property bool failed: false
            stdout: SplitParser {
                onRead: function(line) {
                    try {
                        let msg = JSON.parse(line);
                        if (msg.error) {
                            proc.failed = true;
                            root.showNotice(msg.error, true);
                        }
                    } catch (e) {}
                }
            }
            onExited: {
                if (!proc.failed && proc.okMessage !== "") root.showNotice(proc.okMessage, false);
                destroy(100);
            }
        }
    }

    function run(args, okMessage) {
        runner.createObject(root, { "command": ["python3", root.script].concat(args), "okMessage": okMessage, "running": true });
    }

    function ping(id) { root.run(["ping", id], "Ping sent"); }
    function sendClipboard(id) { root.run(["clipboard", id], "Clipboard sent"); }
    function ring(id) { root.run(["ring", id], "Ringing the phone"); }

    // Links go as a link, anything else as text
    function shareText(id, text) {
        let t = text.trim();
        if (t === "") return;
        let isUrl = /^https?:\/\/\S+$/.test(t);
        root.run([isUrl ? "share-url" : "share-text", id, t], isUrl ? "Link sent" : "Text sent");
    }

    // Opens a file dialog (KDE's, else GTK's), then sends the chosen file
    property string pickTarget: ""

    function pickAndShare(id) {
        if (pickProc.running) return;
        root.pickTarget = id;
        pickProc.running = true;
    }

    Process {
        id: pickProc
        command: ["sh", "-c", "if command -v kdialog >/dev/null; then kdialog --getopenfilename \"$HOME\"; else zenity --file-selection; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let path = text.trim();
                if (path !== "") root.run(["share-file", root.pickTarget, path], "File sent");
            }
        }
    }
}
