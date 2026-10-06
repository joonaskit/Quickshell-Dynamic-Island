import "../.."
import QtQuick
import QtQuick.Layouts

// Inline Reusable SettingSegmented component (Segmented segmented picker)
Rectangle {
    id: segRow
    property string title: ""
    property string description: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
    property var options: []
    property var currentValue: null
    property bool isSubOption: false
    signal selected(var val)

    Layout.fillWidth: true
    implicitHeight: segCol.implicitHeight + 20
    color: "transparent"
    opacity: enabled ? 1.0 : 0.4

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationPopover }
    }

    ColumnLayout {
        id: segCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: segRow.isSubOption ? 28 : 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icon Badge
            Rectangle {
                visible: segRow.iconName !== ""
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 7
                color: segRow.iconBadgeColor

                SvgIcon {
                    anchors.centerIn: parent
                    name: segRow.iconName
                    size: 14
                    color: segRow.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: segRow.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    id: segDescText
                    text: segRow.description
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    visible: text !== ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Segmented Picker Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Repeater {
                    model: segRow.options

                    Rectangle {
                        id: segOptionBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        readonly property bool isSelected: segRow.currentValue === modelData.value
                        color: isSelected ? Qt.rgba(1, 1, 1, 0.22) : (segBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: segOptionBtn.isSelected ? Font.Bold : Font.Normal
                            color: segOptionBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: segBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                segRow.selected(modelData.value);
                            }
                        }
                    }
                }
            }
        }
    }
}
