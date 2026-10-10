pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
        // First line is "text", "none" or the MIME type of non-text content; text follows after it
        command: ["sh", "-c", "command -v wl-paste >/dev/null 2>&1 || exit 0; "
            + "t=$(wl-paste --list-types 2>/dev/null) || { echo none; exit 0; }; "
            + "if printf '%s\\n' \"$t\" | grep -qi '^text/uri-list'; then "
            + "echo files; wl-paste --type text/uri-list 2>/dev/null; "
            + "elif printf '%s\\n' \"$t\" | grep -qiE '^(text/plain|UTF8_STRING|STRING|TEXT)'; then "
            + "echo text; wl-paste -n --type text/plain 2>/dev/null; "
            + "else m=$(printf '%s\\n' \"$t\" | head -n1); echo \"${m:-none}\"; fi"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text === undefined || text === "") return;
                let nl = text.indexOf("\n");
                let kind = nl === -1 ? text : text.slice(0, nl);
                if (kind === "files") {
                    root.currentBinaryType = "";
                    root.currentText = "";
                    root.currentFiles = text.slice(nl + 1).split("\n")
                        .map(l => l.trim())
                        .filter(l => l.startsWith("file://"))
                        .map(l => decodeURIComponent(l.slice(7)));
                    return;
                }
                root.currentFiles = [];
                if (kind === "text") {
                    root.currentBinaryType = "";
                    root.handleNewClipboardText(nl === -1 ? "" : text.slice(nl + 1));
                } else if (kind === "none") {
                    root.currentBinaryType = "";
                    root.handleNewClipboardText("");
                } else {
                    // Non-text content: never read it as text or add it to the history
                    root.currentBinaryType = kind;
                    root.currentText = "";
                    if (kind.startsWith("image/") && root.previewActive) root.fetchImage(kind);
                }
            }
        }
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

    function fetchImage(mime) {
        if (imageProc.running) return;
        imageProc.command = ["sh", "-c",
            "f=\"$1\"; wl-paste --type \"$2\" > \"$f.new\" 2>/dev/null && { cmp -s \"$f.new\" \"$f\" || { mv \"$f.new\" \"$f\"; echo changed; }; }; rm -f \"$f.new\"",
            "sh", root.imagePath, mime];
        imageProc.running = true;
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
        root.currentBinaryType = "";
        root.currentFiles = [];

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
        root.currentBinaryType = "";
        root.currentFiles = [];
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
