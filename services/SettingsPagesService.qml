pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "launcherExtras.js" as LauncherExtras

// The pages of KDE System Settings, for the launcher's settings column. They are
// hidden desktop entries, so scripts/settings_pages.py lists them; the launcher
// asks for a fresh list each time it opens.
Singleton {
    id: root

    // [{ id, name, comment, keywords, icon, command }]
    property var pages: []

    readonly property int limit: 8

    function load() {
        if (!proc.running) proc.running = true;
    }

    // The pages that fit the typed text, best first
    function search(text) {
        return LauncherExtras.matchSettingsPages(root.pages, text, root.limit);
    }

    function open(page) {
        if (page && page.command && page.command.length > 0) Quickshell.execDetached(page.command);
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/settings_pages.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text);
                    if (Array.isArray(list)) root.pages = list;
                } catch (e) {
                    // Keep the list from before
                }
            }
        }
    }
}
