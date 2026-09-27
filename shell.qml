import QtQuick
import Quickshell

ShellRoot {
    id: root

    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            IslandWindow {}
        }
    }

    // Floating Dock (disabled for now)
    /*
    Variants {
        model: Theme.allScreens ? Quickshell.screens : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        delegate: Component {
            DockWindow {}
        }
    }
    */
}
