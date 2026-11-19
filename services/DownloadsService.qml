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

    // The watcher only runs while the dock shows the Downloads item
    readonly property bool enabled: SettingsService.dockShowDownloads

    function applyScan(line) {
        let t = line.trim();
        if (t.length > 0) {
            try {
                let res = JSON.parse(t);
                if (res && res.dir) {
                    root.downloadsDir = res.dir;
                    root.recentFiles = res.files || [];
                }
            } catch (e) {
                console.warn("[DownloadsService] Error parsing downloads JSON:", e);
            }
        }
        root.isScanning = false;
    }

    // Scans again whenever something in the downloads folder changes
    HelperProcess {
        helperId: "downloads"
        helperName: "Downloads watcher"
        wanted: root.enabled
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/downloads_tracker.py", "watch"]
        stdout: SplitParser {
            onRead: line => root.applyScan(line)
        }
    }

    // A one-off scan, for when the stack opens
    Process {
        id: scanProc
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/downloads_tracker.py"]
        stdout: StdioCollector {
            onStreamFinished: root.applyScan(text)
        }
    }

    function refresh() {
        if (root.enabled && !scanProc.running) {
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

