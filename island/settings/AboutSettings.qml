import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Inline components cannot see this file's ids, so they use Theme directly
    component ActionButton: Rectangle {
        id: button

        property string text: ""
        property bool busy: false
        signal clicked()

        Layout.preferredHeight: 26
        Layout.preferredWidth: buttonLabel.implicitWidth + 24
        radius: 13
        color: buttonMouse.containsMouse && !button.busy ? Theme.accentTint(0.3) : Theme.overlay(0.08)
        opacity: button.busy ? 0.4 : 1.0
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
            cursorShape: button.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!button.busy) button.clicked()
        }
    }

    // Persistence Information & Reset
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: persistCol.implicitHeight + 20
        radius: Theme.corner(14)
        color: Qt.rgba(0, 0, 0, 0.3)
        border.width: 1
        border.color: Theme.overlay(0.06)

        ColumnLayout {
            id: persistCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Theme.accentGreen
                }

                Text {
                    text: "Settings saved to: " + SettingsService.settingsFilePath
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                // Reset Button
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: resetRow.implicitWidth + 14
                    radius: 12
                    color: resetMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Theme.overlay(0.08)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    RowLayout {
                        id: resetRow
                        anchors.centerIn: parent
                        spacing: 4

                        SvgIcon {
                            name: "refresh"
                            size: 11
                            color: resetMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                        }

                        Text {
                            text: "Reset Defaults"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: resetMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.resetDefaults()
                    }
                }
            }
        }
    }

    SettingsSection {
        key: "updates"
        title: "UPDATES"
        subtitle: "Check for a newer version of the shell"

        SettingSegmented {
            title: "Update channel"
            description: SettingsService.updateChannel === "stable" ? "New releases only" : "Every new commit on main, before it is released"
            iconName: "download"
            keywords: "stable beta release version upgrade"
            options: [
                { "label": "Stable", "value": "stable" },
                { "label": "Beta", "value": "beta" }
            ]
            currentValue: SettingsService.updateChannel
            onSelected: function(val) { SettingsService.setSetting("updateChannel", val); }
        }

        ColumnLayout {
            id: updateActions

            readonly property bool matchesSearch: SettingsSearch.matches("Check for updates", "update version upgrade restart")
            readonly property var commits: UpdateService.result && UpdateService.result.state === "available" && UpdateService.result.channel === "beta" ? UpdateService.result.commits : []

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 4
            Layout.bottomMargin: 10
            visible: matchesSearch
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    text: "Check for updates"
                    busy: UpdateService.busy
                    onClicked: UpdateService.check()
                }

                ActionButton {
                    visible: UpdateService.canUpdate
                    text: "Update"
                    onClicked: UpdateService.update()
                }

                ActionButton {
                    visible: UpdateService.restartNeeded
                    text: "Restart the shell"
                    onClicked: UpdateService.restart()
                }

                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                text: UpdateService.summary
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: UpdateService.isError ? Theme.accentRed : Theme.textSecondary
            }

            Repeater {
                model: updateActions.commits

                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    text: "• " + modelData
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textTertiary
                }
            }

            Text {
                visible: updateActions.commits.length > 0 && UpdateService.result.behind > updateActions.commits.length
                Layout.fillWidth: true
                Layout.leftMargin: 8
                text: "and " + (UpdateService.result ? UpdateService.result.behind - updateActions.commits.length : 0) + " more"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textTertiary
            }
        }
    }

    SettingsSection {
        key: "welcome"
        title: "WELCOME GUIDE"
        subtitle: "The tour shown on a new install"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "A system check, a few starting choices and tips for the launcher and shortcuts"
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
            }

            ActionButton {
                text: "Show the guide"
                onClicked: OnboardingService.show()
            }
        }
    }

    HealthSection {}

    SettingsSection {
        key: "backup"
        title: "BACKUP"
        subtitle: "Export the configuration to one file, or import it"

        SettingToggle {
            title: "Settings"
            description: "Everything on these pages. The Hue bridge key and paired device ids are left out"
            iconName: "sliders"
            checked: BackupService.includeSettings
            onToggled: function(val) { BackupService.includeSettings = val; }
        }

        SettingToggle {
            title: "Pinned dock apps"
            description: "The apps pinned to the dock and their order"
            iconName: "pin"
            checked: BackupService.includeDock
            onToggled: function(val) { BackupService.includeDock = val; }
        }

        SettingToggle {
            title: "Launcher history"
            description: "Which apps you start and how often. Leave off for a file you share"
            iconName: "clock"
            iconColor: Theme.accentOrange
            checked: BackupService.includeUsage
            onToggled: function(val) { BackupService.includeUsage = val; }
        }

        // Export and Import buttons. Without a file dialog on the system, a path is typed instead
        ColumnLayout {
            id: backupActions

            readonly property bool matchesSearch: SettingsSearch.matches("Export Import Backup", "configuration file restore")

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            visible: matchesSearch
            spacing: 8

            Rectangle {
                visible: !BackupService.pickerAvailable
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: Theme.corner(8)
                color: Theme.overlay(0.05)
                border.width: 1
                border.color: pathInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textPrimary
                    selectionColor: Theme.accentTint(0.4)
                    selectedTextColor: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    text: "~/quickshell-island-config.json"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    text: BackupService.pickerAvailable ? "Export…" : "Export"
                    busy: BackupService.busy
                    onClicked: BackupService.pickerAvailable ? BackupService.pick("export") : BackupService.run("export", pathInput.text)
                }

                ActionButton {
                    text: BackupService.pickerAvailable ? "Import…" : "Import"
                    busy: BackupService.busy
                    onClicked: BackupService.pickerAvailable ? BackupService.pick("import") : BackupService.run("import", pathInput.text)
                }

                Item { Layout.fillWidth: true }
            }

            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: BackupService.notice
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: BackupService.noticeIsError ? Theme.accentRed : Theme.textSecondary
            }

            Text {
                Layout.fillWidth: true
                text: "An import replaces the chosen parts and takes effect at once. The files it replaces are copied to a backup folder first."
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textTertiary
            }
        }
    }
}
