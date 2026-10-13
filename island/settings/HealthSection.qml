import "../.."
import QtQuick
import QtQuick.Layouts

// Health of the shell: the dependency check, the helper scripts and any
// leftover helpers from an earlier run. Shown on the About page.
SettingsSection {
    id: section

    title: "HEALTH"
    subtitle: "What is installed and which helpers are running"

    readonly property var missing: DepsService.report ? DepsService.report.dependencies.filter(d => d.status !== "found") : []

    // Inline components cannot see this file's ids, so they use Theme directly
    component SmallButton: Rectangle {
        id: button

        property string text: ""
        property bool danger: false
        signal clicked()

        Layout.preferredHeight: 26
        Layout.preferredWidth: buttonLabel.implicitWidth + 24
        radius: 13
        color: buttonMouse.containsMouse ? (button.danger ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Theme.accentTint(0.3)) : Theme.overlay(0.08)
        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Theme.textPrimary
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component StatusDot: Rectangle {
        property color dotColor: Theme.accentGreen
        Layout.preferredWidth: 8
        Layout.preferredHeight: 8
        radius: 4
        color: dotColor
    }

    // Re-read the helpers while the page is open
    Timer {
        interval: 10000
        running: section.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: HelperService.scan()
    }

    // Dependency check
    ColumnLayout {
        readonly property bool matchesSearch: SettingsSearch.matches("Health Dependencies Tools", "missing installed check")

        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StatusDot {
                dotColor: DepsService.checking || !DepsService.report ? Theme.overlay(0.3) : (section.missing.length === 0 ? Theme.accentGreen : Theme.accentOrange)
            }

            Text {
                Layout.fillWidth: true
                text: DepsService.checking ? "Checking tools…"
                    : (DepsService.checkFailed ? "The tool check could not run"
                    : (!DepsService.report ? "Not checked yet"
                    : (section.missing.length === 0 ? "All tools found" : section.missing.length + (section.missing.length === 1 ? " tool is" : " tools are") + " missing or not running")))
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Theme.textPrimary
            }

            SmallButton {
                text: "Check again"
                onClicked: DepsService.runCheck()
            }
        }

        Repeater {
            model: section.missing

            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 16
                text: modelData.name + (modelData.status === "not-running" ? " is installed but not running" : " is not installed" + (modelData.package ? " (package: " + modelData.package + ")" : ""))
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
            }
        }
    }

    SettingDivider {}

    // Helper scripts, updated live
    ColumnLayout {
        readonly property bool matchesSearch: SettingsSearch.matches("Helpers", "scripts running crashed restarted")

        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 6

        Repeater {
            model: HelperService.entries

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                StatusDot {
                    dotColor: !modelData.running ? Theme.accentRed : (modelData.crashes > 0 ? Theme.accentOrange : Theme.accentGreen)
                }

                Text {
                    text: modelData.name
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: HelperService.statusText(modelData)
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: modelData.running && modelData.crashes === 0 ? Theme.textSecondary : Theme.accentOrange
                }
            }
        }
    }

    // Leftover helpers from an earlier run
    RowLayout {
        readonly property bool matchesSearch: SettingsSearch.matches("Stale helpers", "duplicate orphaned processes")

        visible: HelperService.stale.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 8
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: HelperService.stale.length + (HelperService.stale.length === 1 ? " leftover helper process is" : " leftover helper processes are") + " running from an earlier session (" + HelperService.stale.map(s => s.script).join(", ") + "). They can break the dock indicators."
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.accentOrange
        }

        SmallButton {
            text: "Stop them"
            danger: true
            onClicked: HelperService.stopStale()
        }
    }

    SettingDivider {}

    // Actions
    ColumnLayout {
        readonly property bool matchesSearch: SettingsSearch.matches("Restart helpers Copy report", "diagnostic bug")

        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SmallButton {
                text: "Restart helpers"
                onClicked: HelperService.restartAll()
            }

            SmallButton {
                text: "Copy report"
                onClicked: HelperService.copyReport()
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            visible: HelperService.notice !== ""
            Layout.fillWidth: true
            text: HelperService.notice
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.textSecondary
        }

        Text {
            Layout.fillWidth: true
            text: "The report lists versions, the tool check and the helper states for a bug report. It holds no settings, tokens or addresses, and your home folder is shown as ~."
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.textTertiary
        }
    }
}
