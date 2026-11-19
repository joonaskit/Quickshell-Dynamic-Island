import QtQuick
import Quickshell.Io

// A small local file's text, read on first use and again on every change, including a
// file replaced by a rename as most programs save. Bind to `text`; it is "" while the
// file is missing. Taken from Omarchy's shell.
//
// Every read is synchronous: FileView's reload() joins a background read already
// running, which would keep a replaced file's old contents.
QtObject {
    id: root

    property string path: ""
    readonly property string text: reader.text()

    // Watch first, then read: reload() reads and only then replaces its watcher, so a
    // change landing between the two would be lost
    function reread() {
        watcher.reload();
        reader.reload();
    }

    // Both FileViews follow `path` in no set order, so read again once both have
    onPathChanged: Qt.callLater(() => root.reader.reload())

    readonly property FileView reader: FileView {
        path: root.path
        printErrors: false
        preload: false
        blockAllReads: true
    }

    readonly property FileView watcher: FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        preload: false
        onFileChanged: root.reread()
    }
}
