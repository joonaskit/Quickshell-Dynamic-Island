import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Persistence Information & Reset
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: persistCol.implicitHeight + 20
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.3)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

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
                    width: 8
                    height: 8
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
                    color: resetMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Qt.rgba(1, 1, 1, 0.08)

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
}
