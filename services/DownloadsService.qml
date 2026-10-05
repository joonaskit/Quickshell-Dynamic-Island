pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string downloadsDir: ""
    property var recentFiles: []
    property bool isScanning: false

    // Scanner process that queries the downloads folder and recent files
    Process {
        id: scanProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/downloads_tracker.py"]

        stdout: StdioCollector {
            onTextChanged: {
                let t = text.trim();
                if (t.length > 0) {
                    try {
                        let res = JSON.parse(t);
                        if (res && res.dir) {
                            root.downloadsDir = res.dir;
                            root.recentFiles = res.files || [];
                        }
                    } catch(e) {
                        console.warn("[DownloadsService] Error parsing downloads JSON:", e);
                    }
                }
                root.isScanning = false;
            }
        }
    }

    // Auto-refresh timer
    Timer {
        interval: 8000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.refresh();
    }

    function refresh() {
        if (!scanProc.running) {
            root.isScanning = true;
            scanProc.running = true;
        }
    }

    function openFolder() {
        let home = Quickshell.env("HOME");
        let dir = root.downloadsDir || (home + "/Downloads");
        Quickshell.execDetached(["xdg-open", dir]);
    }

    function openFile(filePath) {
        if (!filePath) return;
        Quickshell.execDetached(["xdg-open", filePath]);
    }
}

