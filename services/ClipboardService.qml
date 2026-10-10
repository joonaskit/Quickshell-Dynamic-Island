pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "clipboardHistory.js" as History

Singleton {
    id: root

    property string currentText: ""
    // MIME type of a non-text clipboard (e.g. "image/png"), empty when the clipboard holds text or nothing
    property string currentBinaryType: ""
    // Preview of a copied image: a temp file plus a counter that changes whenever its content does
    readonly property string imagePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard-image"
    property int imageVersion: 0
    // Set while the clipboard menu is open; the image is only read from the clipboard then
    property bool previewActive: false
    onPreviewActiveChanged: {
        if (previewActive && currentBinaryType.startsWith("image/")) fetchImage(currentBinaryType);
    }
    // Copied files (e.g. from a file manager): decoded paths, and the first image among them for the preview
    property var currentFiles: []
    readonly property string filePreviewPath: {
        for (let f of currentFiles) {
            if (/\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(f)) return f;
        }
        return "";
    }
    readonly property string imageSource: filePreviewPath !== "" ? "file://" + encodeURI(filePreviewPath)
        : (currentBinaryType.startsWith("image/") && imageVersion > 0 ? "file://" + imagePath + "?v=" + imageVersion : "")
    // Recent copies, newest first; entries are described in clipboardHistory.js. Held in
    // memory only: nothing is written to disk and it is gone when the shell stops.
    property var history: []
    property int nextId: 1
    // Whether the clipboard history window is open
    property bool windowOpen: false
    // Where the window sits, in pixels from the top left of the screen; negative until first shown
    property real windowX: -1
    property real windowY: -1
    property bool isAvailable: true
    readonly property int maxHistory: SettingsService.clipboardMaxItems

    // Why the clipboard content is not shown or recorded: "secret" (marked by a password
    // manager), "ignored" (copied in an ignored app), "paused" (incognito) or "" for none
    property string hiddenReason: ""
    readonly property string hiddenText: {
        switch (hiddenReason) {
        case "secret": return "Hidden: copied from a password manager";
        case "ignored": return "Hidden: copied in an ignored app";
        case "paused": return "Paused: incognito mode is on";
        }
        return "";
    }
    // Whether the text on the clipboard looks like a credential, so views should not show it
    readonly property bool currentSensitive: currentText !== "" && history.some(e => e.sensitive && e.text === currentText)
    // While true, text copies are not recorded
    property bool incognito: false
    // Text we just put on the clipboard ourselves, so the tracker's report of it is not a new copy
    property string suppressText: ""

    onMaxHistoryChanged: root.history = History.trim(root.history, root.maxHistory)
    onIncognitoChanged: {
        if (incognito) {
            root.hideCurrent("paused");
        } else if (root.hiddenReason === "paused") {
            // What was copied meanwhile stays unrecorded; the next copy shows up as usual
            root.hiddenReason = "";
        }
    }

    // Reports every clipboard change as a JSON line (see scripts/clipboard_tracker.py)
    Process {
        id: trackerProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/clipboard_tracker.py"]
        running: true
        stdout: SplitParser {
            onRead: line => root.handleRecord(line)
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 5000
        onTriggered: trackerProc.running = true
    }

    // Drops credential-like entries once they have been around long enough
    Timer {
        interval: 5000
        running: root.history.length > 0
        repeat: true
        onTriggered: {
            let kept = History.expireSensitive(root.history, Date.now(), SettingsService.clipboardSensitiveExpiry);
            if (kept !== root.history) root.history = kept;
        }
    }

    // Clears the clipboard
    Process {
        id: clearProc
        command: ["sh", "-c", "wl-copy -c 2>/dev/null; wl-copy -c -p 2>/dev/null || true"]
    }

    // Sets the clipboard
    Process {
        id: copyProc
    }

    // Saves the clipboard image to a temp file and reports whether it differs from the previous one
    Process {
        id: imageProc
        stdout: StdioCollector {
            onTextChanged: {
                if (text.indexOf("changed") !== -1) root.imageVersion++;
            }
        }
    }

    function fetchImage(mime) {
        if (imageProc.running) return;
        imageProc.command = ["sh", "-c",
            "f=\"$1\"; wl-paste --type \"$2\" > \"$f.new\" 2>/dev/null && { cmp -s \"$f.new\" \"$f\" || { mv \"$f.new\" \"$f\"; echo changed; }; }; rm -f \"$f.new\"",
            "sh", root.imagePath, mime];
        imageProc.running = true;
    }

    function toggleWindow() {
        root.windowOpen = !root.windowOpen;
    }

    function sourceApp() {
        let app = WindowService.activeAppId;
        return { "app": app, "title": app !== "" ? WindowService.activeAppTitle : "" };
    }

    function clearCurrent() {
        root.currentText = "";
        root.currentBinaryType = "";
        root.currentFiles = [];
    }

    function hideCurrent(reason) {
        root.clearCurrent();
        root.hiddenReason = reason;
    }

    function handleRecord(line) {
        let rec;
        try {
            rec = JSON.parse(line);
        } catch (e) {
            console.warn("[ClipboardService] Bad tracker line:", e);
            return;
        }

        let own = root.suppressText;
        root.suppressText = "";
        if ((rec.type === "text" && rec.text === own) || (rec.type === "secret" && own !== "")) return;

        switch (rec.type) {
        case "text": {
            let source = root.sourceApp();
            if (root.incognito) {
                root.hideCurrent("paused");
            } else if (History.isIgnoredApp(source.app, SettingsService.clipboardIgnoredApps)) {
                root.hideCurrent("ignored");
            } else {
                root.clearCurrent();
                root.hiddenReason = "";
                root.currentText = rec.text;
                root.history = History.trim(History.addCopy(root.history, rec, source, root.nextId++), root.maxHistory);
            }
            break;
        }
        case "files":
            root.clearCurrent();
            root.hiddenReason = "";
            root.currentFiles = rec.files;
            break;
        case "image":
        case "other":
            root.clearCurrent();
            root.hiddenReason = "";
            root.currentBinaryType = rec.mime;
            if (rec.mime.startsWith("image/") && root.previewActive) root.fetchImage(rec.mime);
            break;
        case "secret":
            root.hideCurrent("secret");
            break;
        default:
            root.clearCurrent();
            root.hiddenReason = "";
        }
    }

    // Puts a history entry's text back on the clipboard and moves it to the front
    function copyEntry(id) {
        let idx = root.history.findIndex(e => e.id === id);
        if (idx === -1) return;
        let entry = root.history[idx];
        let list = root.history.slice();
        list.splice(idx, 1);
        list.unshift(Object.assign({}, entry, { "time": Date.now() }));
        root.history = list;

        root.clearCurrent();
        root.hiddenReason = "";
        root.currentText = entry.text;
        root.suppressText = entry.text;
        // Credential-like text is marked so other clipboard managers skip it too; older
        // wl-clipboard releases lack --sensitive, so fall back to a plain copy
        copyProc.command = entry.sensitive
            ? ["sh", "-c", "wl-copy --sensitive -- \"$1\" 2>/dev/null || wl-copy -- \"$1\"", "sh", entry.text]
            : ["wl-copy", "--", entry.text];
        copyProc.running = true;
    }

    function clearClipboard() {
        root.clearCurrent();
        root.hiddenReason = "";
        root.history = root.history.filter(e => e.pinned);
        root.suppressText = "";
        if (!clearProc.running) {
            clearProc.running = true;
        }
    }

    // Removes an entry; if it is what the clipboard holds right now, the clipboard is cleared too
    function removeEntry(id) {
        let entry = root.history.find(e => e.id === id);
        if (!entry) return;
        root.history = root.history.filter(e => e.id !== id);
        if (entry.text === root.currentText) {
            root.clearCurrent();
            if (!clearProc.running) clearProc.running = true;
        }
    }

    function togglePinned(id) {
        root.history = root.history.map(e => e.id === id ? Object.assign({}, e, { "pinned": !e.pinned }) : e);
    }
}
