pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "niriState.js" as NiriState
import "restartDelay.js" as RestartDelay

// niri's windows, workspaces and overview, read from its event stream on $NIRI_SOCKET,
// and niri actions sent over the same socket. Runs only under niri (CompositorService).
// The state is built by niriState.js; this holds the sockets. See docs/NIRI.md.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
    readonly property bool active: CompositorService.isNiri && root.socketPath !== ""
    // True while the event stream is open and niri has sent its state
    property bool ready: false

    // Workspaces sorted by output and index, each with windowCount (niriState.js)
    property var workspaces: []
    // Windows ordered by workspace and column, as niri sends them
    property var windows: []
    property var focusedWindow: null
    property string focusedOutput: ""
    property bool overviewOpen: false
    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0
    // Config loads after niri's own at start, and whether the last one failed
    property int configReloads: 0
    property bool configFailed: false

    property var state: NiriState.emptyState()

    // What niri's config says about blurring the shell's surfaces (scripts/niri_blur.py):
    // { enabled, blurred, blockedBy, xrayOff, suggestedRule, path }, null until read.
    // Re-read when config.kdl changes (Theme.niriConfig); files it includes are not watched.
    property var blur: null
    // False only under niri when its config keeps the island from being blurred
    readonly property bool shellBlurred: !root.active || !root.blur || root.blur.blurred === undefined
        || root.blur.blurred.indexOf("quickshell-island") >= 0

    function readBlur() {
        if (root.active) blurProc.running = true;
    }

    Process {
        id: blurProc
        command: ["python3", Quickshell.shellDir + "/scripts/niri_blur.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.blur = JSON.parse(text);
                } catch (e) {
                    root.blur = null;
                }
            }
        }
    }

    Connections {
        target: root.active ? Theme.niriConfig : null
        function onTextChanged() { root.readBlur(); }
    }

    // Runs a niri action: name as niri's IPC names it ("FocusWindow"), fields its
    // arguments ({ "id": 3 }). onReply, if given, gets the parsed reply.
    function action(name, fields, onReply) {
        root.request(NiriState.actionRequest(name, fields), onReply);
    }

    // Sends a request line ("\"Outputs\"\n") and passes the parsed reply to onReply
    function request(line, onReply) {
        if (!root.active) return;
        root.pending.push({ "line": line, "onReply": onReply || null });
        root.sendNext();
    }

    function publish() {
        let s = root.state;
        root.workspaces = NiriState.workspaceList(s);
        root.windows = NiriState.windowList(s);
        root.focusedWindow = NiriState.focusedWindow(s);
        root.focusedOutput = NiriState.focusedOutput(s);
        root.overviewOpen = s.overviewOpen;
        root.keyboardLayouts = s.keyboardLayouts;
        root.keyboardLayoutIndex = s.keyboardLayoutIndex;
        root.configReloads = Math.max(0, s.configLoads - 1);
        root.configFailed = s.configFailed;
        root.ready = true;
    }

    // ---- Event stream ----

    property double connectedAt: 0
    property int quickDrops: 0

    function connectStream() {
        if (!root.active || stream.connected) return;
        stream.connected = true;
    }

    Component.onCompleted: {
        root.connectStream();
        root.readBlur();
    }

    Socket {
        id: stream
        path: root.socketPath

        onConnectionStateChanged: {
            if (stream.connected) {
                root.connectedAt = Date.now();
                root.state = NiriState.emptyState();
                stream.write("\"EventStream\"\n");
                stream.flush();
                return;
            }
            root.ready = false;
            if (!root.active) return;
            // niri restarted or the stream broke: try again, slower if it keeps dropping
            root.quickDrops = RestartDelay.countQuickExits(root.quickDrops, Date.now() - root.connectedAt);
            reconnect.interval = RestartDelay.delay(500, root.quickDrops);
            reconnect.restart();
            console.warn("[NiriService] Event stream closed, reconnecting in " + reconnect.interval + " ms");
        }

        onError: function(error) {
            if (!stream.connected && root.active) {
                reconnect.interval = RestartDelay.delay(500, ++root.quickDrops);
                reconnect.restart();
            }
        }

        parser: SplitParser {
            onRead: function(line) {
                if (NiriState.applyLine(root.state, line)) Qt.callLater(root.publish);
            }
        }
    }

    Timer {
        id: reconnect
        onTriggered: root.connectStream()
    }

    // ---- Requests, one per connection: the event stream takes none ----

    property var pending: []
    property var current: null

    function sendNext() {
        if (root.current || root.pending.length === 0) return;
        root.current = root.pending.shift();
        requests.connected = true;
    }

    function finishRequest(reply) {
        let done = root.current;
        root.current = null;
        requests.connected = false;
        if (done && done.onReply) {
            try {
                done.onReply(reply);
            } catch (e) {
                console.warn("[NiriService] Reply handler failed: " + e);
            }
        }
        Qt.callLater(root.sendNext);
    }

    Socket {
        id: requests
        path: root.socketPath

        onConnectionStateChanged: {
            if (requests.connected && root.current) {
                requests.write(root.current.line);
                requests.flush();
            } else if (!requests.connected && root.current) {
                root.finishRequest(null);
            }
        }

        onError: function(error) {
            if (root.current) root.finishRequest(null);
        }

        parser: SplitParser {
            onRead: function(line) {
                let reply = null;
                try {
                    reply = JSON.parse(line);
                } catch (e) {}
                if (reply && reply.Err !== undefined) console.warn("[NiriService] niri refused a request: " + reply.Err);
                if (root.current) root.finishRequest(reply);
            }
        }
    }
}
