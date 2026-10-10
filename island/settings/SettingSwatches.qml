import "../.."
import QtQuick
import QtQuick.Layouts

// Setting row with a line of color swatches to pick one from
Rectangle {
    id: swatchRow
    property string title: ""
    property string description: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
    // [{ name, label, color, hollow }]. A hollow swatch is drawn as a ring, to set
    // apart an option that follows another color rather than being one.
    property var options: []
    property string currentValue: ""
    signal selected(string val)

    readonly property bool matchesSearch: SettingsSearch.matches(title, description)

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: swatchCol.implicitHeight + 20
    color: "transparent"

    ColumnLayout {
        id: swatchCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Icon Badge
            Rectangle {
                visible: swatchRow.iconName !== ""
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: Theme.corner(7)
                color: swatchRow.iconBadgeColor

                SvgIcon {
                    anchors.centerIn: parent
                    name: swatchRow.iconName
                    size: 14
                    color: swatchRow.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: swatchRow.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: swatchRow.description
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    visible: text !== ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Name of the selected color
            Text {
                text: {
                    for (let i = 0; i < swatchRow.options.length; i++) {
                        if (swatchRow.options[i].name === swatchRow.currentValue) return swatchRow.options[i].label;
                    }
                    return "";
                }
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textSecondary
            }
        }

        // Swatches
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: swatchRow.options

                // Each swatch gets an equal share of the row, with the dot centred in it
                delegate: Item {
                    id: swatch

                    required property var modelData
                    readonly property bool isSelected: swatchRow.currentValue === modelData.name

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    // Selection ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: "transparent"
                        border.width: 2
                        border.color: swatch.modelData.color
                        opacity: swatch.isSelected ? 1.0 : 0.0

                        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 10
                        color: swatch.modelData.hollow ? "transparent" : swatch.modelData.color
                        border.width: swatch.modelData.hollow ? 4 : 0
                        border.color: swatch.modelData.color
                        scale: swatchMouse.pressed ? 0.9 : (swatchMouse.containsMouse ? 1.12 : 1.0)

                        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: swatchRow.selected(swatch.modelData.name)
                    }
                }
            }
        }
    }
}
