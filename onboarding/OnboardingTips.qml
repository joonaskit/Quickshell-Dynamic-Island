import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell

// Step 5: how to reach things from the keyboard. The commands are the IPC calls
// in run.sh, shown with the shell's real path so they can be pasted as they are.
OnboardingPage {
    id: page

    readonly property string runner: Quickshell.shellDir + "/run.sh"

    title: "Tips and shortcuts"
    intro: "The launcher, the window switcher and the clipboard history open with a command, so you can give each one a keyboard shortcut."

    Repeater {
        model: [
            { "title": "App launcher", "text": "Search and start apps", "flag": "-l" },
            { "title": "Window switcher", "text": "The launcher, opened on its list of open windows", "flag": "-w" },
            { "title": "Clipboard history", "text": "What you copied, with search and pinning", "flag": "-v" },
            { "title": "Expanded view", "text": "Open or close the island's panel", "flag": "-t" }
        ]

        RowLayout {
            id: tip
            required property var modelData
            readonly property string command: page.runner + " " + modelData.flag

            Layout.fillWidth: true
            spacing: Theme.px(12)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(1)

                Text {
                    text: tip.modelData.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text: tip.modelData.text
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    color: Theme.textSecondary
                }

                Text {
                    Layout.fillWidth: true
                    text: tip.command
                    elide: Text.ElideMiddle
                    font.family: "monospace"
                    font.pixelSize: Theme.fontPx(10)
                    color: Theme.textTertiary
                }
            }

            OnboardingButton {
                text: OnboardingService.copied === tip.command ? "Copied" : "Copy"
                onClicked: OnboardingService.copy(tip.command)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.overlay(0.08)
    }

    Text {
        Layout.fillWidth: true
        text: "The Shortcuts page in Settings binds these, and the volume, brightness, media and timer controls, to keys for you. It saves them in KDE's own shortcut settings."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(12)
        color: Theme.textSecondary
    }

    OnboardingButton {
        text: "Open the Shortcuts settings"
        onClicked: {
            OnboardingService.close();
            SettingsService.requestOpenSettings("Shortcuts");
        }
    }
}
