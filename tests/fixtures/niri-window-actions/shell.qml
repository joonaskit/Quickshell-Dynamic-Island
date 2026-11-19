import QtQuick
import Quickshell
import "fixture"

// Under niri the dock's window list comes from niri's windows, and closing one from the
// dock menu (WindowService.closeWindow for a tracked window) sends CloseWindow by its id.
ShellRoot {
    id: root

    function calculator() {
        return DockService.getMergedWindows().find(w => w.appId === "org.gnome.Calculator");
    }

    NiriActions {
        id: niri
    }

    Steps {
        id: steps
        steps: [
            { name: "stream read", until: () => NiriService.ready && WindowService.windowList.length > 0 },
            {
                name: "window listed",
                until: () => root.calculator() !== undefined
                    && steps.expect("tracked", root.calculator().tracked, true)
                    && steps.expect("id", root.calculator().id, "13")
            },
            {
                name: "close sends CloseWindow",
                run: () => WindowService.closeWindow(root.calculator().id),
                until: () => niri.has('{"Action":{"CloseWindow":{"id":13}}}')
            }
        ]
    }
}
