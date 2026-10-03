import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // IPC handler for external scripts / shortcuts
    IpcHandler {
        target: "launcher"

        function toggle() {
            DockService.toggleAppLauncherRequested();
        }
    }

    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            IslandWindow {}
        }
    }

    // Floating Dock (disabled for now)
    
    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            DockWindow {}
        }
    }
    
}
