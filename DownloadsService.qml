pragma Singleton
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
        command: ["python3", "-c", `
import os, glob, subprocess, json

def get_downloads():
    dl_dir = None
    try:
        p = subprocess.check_output(['xdg-user-dir', 'DOWNLOAD'], text=True).strip()
        if os.path.exists(p): dl_dir = p
    except: pass
    if not dl_dir:
        for cand in [os.path.expanduser('~/Downloads'), os.path.expanduser('~/Lataukset'), os.path.expanduser('~/code')]:
            if os.path.exists(cand):
                dl_dir = cand
                break
    if not dl_dir:
        dl_dir = os.path.expanduser('~')

    items = []
    try:
        entries = [os.path.join(dl_dir, f) for f in os.listdir(dl_dir) if not f.startswith('.')]
        entries.sort(key=lambda x: os.path.getmtime(x), reverse=True)
        for path in entries[:10]:
            name = os.path.basename(path)
            is_dir = os.path.isdir(path)
            try:
                size_bytes = os.path.getsize(path) if not is_dir else 0
            except:
                size_bytes = 0
            if is_dir:
                size_str = 'Folder'
            elif size_bytes < 1024:
                size_str = f'{size_bytes} B'
            elif size_bytes < 1024 * 1024:
                size_str = f'{size_bytes / 1024:.1f} KB'
            elif size_bytes < 1024 * 1024 * 1024:
                size_str = f'{size_bytes / (1024*1024):.1f} MB'
            else:
                size_str = f'{size_bytes / (1024*1024*1024):.1f} GB'

            ext = os.path.splitext(name)[1].lower()
            icon = 'folder' if is_dir else 'text-x-generic'
            if ext in ['.png', '.jpg', '.jpeg', '.svg', '.webp', '.gif']: icon = 'image-x-generic'
            elif ext in ['.mp4', '.mkv', '.webm', '.avi']: icon = 'video-x-generic'
            elif ext in ['.mp3', '.flac', '.wav', '.ogg', '.m4a']: icon = 'audio-x-generic'
            elif ext in ['.zip', '.tar', '.gz', '.7z', '.bz2', '.xz']: icon = 'package-x-generic'
            elif ext in ['.pdf']: icon = 'application-pdf'
            elif ext in ['.sh', '.py', '.js', '.ts', '.qml', '.json']: icon = 'text-x-script'

            items.append({
                'name': name,
                'path': path,
                'isDir': is_dir,
                'size': size_str,
                'icon': icon
            })
    except Exception as e:
        pass
    return {'dir': dl_dir, 'files': items}

print(json.dumps(get_downloads()))
`]

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
        let dir = root.downloadsDir || "~/Downloads";
        Quickshell.execDetached(["xdg-open", dir]);
    }

    function openFile(filePath) {
        if (!filePath) return;
        Quickshell.execDetached(["xdg-open", filePath]);
    }
}

