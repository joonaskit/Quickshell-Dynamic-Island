import QtQuick
import Quickshell
import "fixture"

// When niri's event stream closes (niri restarted), NiriService reconnects and builds
// its state again from the new stream.
ShellRoot {
    id: root

    NiriActions {
        id: niri
    }

    Steps {
        id: steps
        timeout: 5000
        steps: [
            { name: "stream read", until: () => NiriService.ready && NiriService.workspaces.length === 4 },
            { name: "stream dropped", run: () => niri.dropStreams(), until: () => !NiriService.ready },
            {
                name: "state back",
                until: () => NiriService.ready && NiriService.workspaces.length === 4
                    && steps.expect("focused output", NiriService.focusedOutput, "HDMI-A-1")
            }
        ]
    }
}
