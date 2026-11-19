import QtQuick
import Quickshell
import "fixture"

// Under niri the virtual desktops pill lists one output's workspaces from the event
// stream (tests/fake_niri.py serves the recording), and stepping it sends FocusWorkspace.
ShellRoot {
    id: root

    VirtualDesktopsPill {
        id: pill
        screenName: "HDMI-A-1"
    }

    NiriActions {
        id: niri
    }

    Steps {
        id: steps
        steps: [
            { name: "niri detected", until: () => steps.expect("isNiri", CompositorService.isNiri, true) },
            { name: "stream read", until: () => NiriService.ready && NiriService.workspaces.length === 4 },
            {
                name: "this output's workspaces",
                until: () => steps.expect("ids", pill.desktops.map(d => d.id).join(","), "3,4")
                    && steps.expect("current", pill.currentId, "4")
                    && steps.expect("urgent", pill.desktops[0].urgent, true)
            },
            {
                name: "step sends FocusWorkspace",
                run: () => pill.step(-1),
                until: () => niri.has('{"Action":{"FocusWorkspace":{"reference":{"Id":3}}}}')
            }
        ]
    }
}
