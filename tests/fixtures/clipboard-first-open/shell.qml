import QtQuick
import Quickshell
import "fixture"

// ClipboardWindow builds its card on the first open and keeps it: nothing exists while
// it has never been shown, the card fades in on the first open, and closing and
// reopening reuses the same card (CODING_STANDARDS.md, building windows on first open).
ShellRoot {
    id: root

    property var firstCard: null

    ClipboardWindow {
        id: clipboard
        modelData: Quickshell.screens[0]
    }

    Steps {
        id: steps
        steps: [
            {
                name: "never opened",
                until: () => steps.expect("content", clipboard.content, null) && steps.expect("visible", clipboard.visible, false)
            },
            {
                name: "first open",
                run: () => ClipboardService.windowOpen = true,
                until: () => clipboard.content !== null && clipboard.visible && clipboard.content.opacity === 1
            },
            {
                name: "closed",
                run: () => {
                    root.firstCard = clipboard.content;
                    clipboard.content.searchField.text = "kept";
                    ClipboardService.windowOpen = false;
                },
                until: () => !clipboard.visible
            },
            {
                name: "kept while closed",
                until: () => steps.expect("content is the first card", clipboard.content === root.firstCard, true)
            },
            {
                name: "reopened",
                run: () => ClipboardService.windowOpen = true,
                until: () => clipboard.visible && clipboard.content.opacity === 1
            },
            {
                name: "same card",
                until: () => steps.expect("content is the first card", clipboard.content === root.firstCard, true)
                    && steps.expect("search text", clipboard.content.searchField.text, "")
            }
        ]
    }
}
