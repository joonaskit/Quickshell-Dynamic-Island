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
    // A copied image, saved by the tracker as a file in a RAM-backed temp folder
    property string currentImagePath: ""
    // Copied files (e.g. from a file manager): decoded paths, and the first image among them for the preview
    property var currentFiles: []
    readonly property string imageSource: {
        if (currentImagePath !== "") return History.fileUrl(currentImagePath);
        for (let f of currentFiles) {
            if (/\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(f)) return History.fileUrl(f);
        }
        return "";
    }
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
    // Key (see History.recordKey) of what the clipboard holds now, if it is in the history
    readonly property string currentKey: currentText !== "" ? "text:" + currentText
        : (currentImagePath !== "" ? "image:" + currentImagePath.split("/").pop().split(".")[0]
        : (currentFiles.length > 0 ? "files:" + currentFiles.join("\n") : ""))
    // While true, text copies are not recorded
    property bool incognito: false
    // Key (see History.recordKey) of what we just put on the clipboard ourselves, so the
    // tracker's report of it is not a new copy
    property string suppressKey: ""

    // Replaces the history, deleting the image files of entries that are gone
    function setHistory(list) {
        let kept = new Set(list.map(e => e.path));
        let gone = root.history.filter(e => e.type === "image" && !kept.has(e.path));
        if (gone.length > 0) Quickshell.execDetached(["rm", "-f", ...gone.map(e => e.path)]);
        root.history = list;
    }

    onMaxHistoryChanged: root.setHistory(History.trim(root.history, root.maxHistory))
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
            if (kept !== root.history) root.setHistory(kept);
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
        root.currentImagePath = "";
        root.currentFiles = [];
    }

    function hideCurrent(reason) {
        root.clearCurrent();
        root.hiddenReason = reason;
    }

    // Shows a text, image or files copy as the current content and records it in the history
    function handleCopy(rec) {
        let source = root.sourceApp();
        let hidden = root.incognito ? "paused"
            : (History.isIgnoredApp(source.app, SettingsService.clipboardIgnoredApps) ? "ignored" : "");
        if (hidden !== "") {
            root.hideCurrent(hidden);
            // An image that is not recorded must not stay on disk either
            if (rec.type === "image" && !root.history.some(e => e.path === rec.path)) Quickshell.execDetached(["rm", "-f", rec.path]);
            return;
        }
        root.clearCurrent();
        root.hiddenReason = "";
        if (rec.type === "text") root.currentText = rec.text;
        else if (rec.type === "image") {
            root.currentBinaryType = rec.mime;
            root.currentImagePath = rec.path;
        } else root.currentFiles = rec.files;
        root.setHistory(History.trim(History.addCopy(root.history, rec, source, root.nextId++), root.maxHistory));
    }

    function handleRecord(line) {
        let rec;
        try {
            rec = JSON.parse(line);
        } catch (e) {
            console.warn("[ClipboardService] Bad tracker line:", e);
            return;
        }

        let own = root.suppressKey;
        root.suppressKey = "";
        if ((rec.type === "secret" && own !== "") || (own !== "" && ["text", "image", "files"].includes(rec.type) && History.recordKey(rec) === own)) return;

        switch (rec.type) {
        case "text":
        case "image":
        case "files":
            root.handleCopy(rec);
            break;
        case "other":
            root.clearCurrent();
            root.hiddenReason = "";
            root.currentBinaryType = rec.mime;
            break;
        case "secret":
            root.hideCurrent("secret");
            break;
        default:
            root.clearCurrent();
            root.hiddenReason = "";
        }
    }

    // Puts a history entry back on the clipboard and moves it to the front
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
        root.suppressKey = History.entryKey(entry);
        if (entry.type === "image") {
            root.currentBinaryType = entry.mime;
            root.currentImagePath = entry.path;
            copyProc.command = ["sh", "-c", "wl-copy --type \"$1\" < \"$2\"", "sh", entry.mime, entry.path];
        } else if (entry.type === "files") {
            root.currentFiles = entry.files;
            copyProc.command = ["sh", "-c", "printf '%s\\r\\n' \"$@\" | wl-copy --type text/uri-list", "sh", ...entry.files.map(History.fileUrl)];
        } else {
            root.currentText = entry.text;
            // Credential-like text is marked so other clipboard managers skip it too; older
            // wl-clipboard releases lack --sensitive, so fall back to a plain copy
            copyProc.command = entry.sensitive
                ? ["sh", "-c", "wl-copy --sensitive -- \"$1\" 2>/dev/null || wl-copy -- \"$1\"", "sh", entry.text]
                : ["wl-copy", "--", entry.text];
        }
        copyProc.running = true;
    }

    function clearClipboard() {
        root.clearCurrent();
        root.hiddenReason = "";
        root.setHistory(root.history.filter(e => e.pinned));
        root.suppressKey = "";
        if (!clearProc.running) {
            clearProc.running = true;
        }
    }

    // Removes an entry; if it is what the clipboard holds right now, the clipboard is cleared too
    function removeEntry(id) {
        let entry = root.history.find(e => e.id === id);
        if (!entry) return;
        root.setHistory(root.history.filter(e => e.id !== id));
        if (History.entryKey(entry) === root.currentKey) {
            root.clearCurrent();
            if (!clearProc.running) clearProc.running = true;
        }
    }

    function togglePinned(id) {
        root.history = root.history.map(e => e.id === id ? Object.assign({}, e, { "pinned": !e.pinned }) : e);
    }
}
