import "../.."
import QtQuick
import QtQuick.Layouts

// One-line setting with a small segmented picker on the right, for a choice of a few
// short options (Off / Show / Auto-hide) that would otherwise be a toggle and a sub-toggle
Rectangle {
    id: choiceRow
    property string title: ""
    property string description: ""
    // Shown in place of the description, in orange, for example a missing tool
    property string warning: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    property var options: []
    property var currentValue: null
    property bool isSubOption: false
    signal selected(var val)

    // Other words this row is found by in the search, not shown
    property string keywords: ""
    readonly property bool matchesSearch: SettingsSearch.matches(title, description, keywords)

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: (description !== "" || warning !== "") ? 52 : 42
    color: "transparent"
    radius: Theme.corner(10)
    opacity: enabled ? 1.0 : 0.4

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationPopover }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: choiceRow.isSubOption ? 28 : 12
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            visible: choiceRow.iconName !== ""
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: Theme.corner(7)
            color: Qt.rgba(choiceRow.iconColor.r, choiceRow.iconColor.g, choiceRow.iconColor.b, 0.18)

            SvgIcon {
                anchors.centerIn: parent
                name: choiceRow.iconName
                size: 14
                color: choiceRow.iconColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: choiceRow.title
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: choiceRow.warning !== "" ? choiceRow.warning : choiceRow.description
                visible: text !== ""
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: choiceRow.warning !== "" ? Theme.accentOrange : Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        // Picker, as wide as its labels
        Rectangle {
            Layout.preferredWidth: optionsRow.implicitWidth + 4
            Layout.preferredHeight: 26
            radius: Theme.corner(8)
            color: Theme.overlay(0.08)

            RowLayout {
                id: optionsRow
                anchors.fill: parent
                anchors.margins: 2
                spacing: 2

                Repeater {
                    model: choiceRow.options

                    Rectangle {
                        id: optionBtn
                        required property var modelData
                        readonly property bool isSelected: choiceRow.currentValue === modelData.value

                        Layout.fillHeight: true
                        Layout.preferredWidth: optionLabel.implicitWidth + 20
                        radius: Theme.corner(6)
                        color: isSelected ? Theme.overlay(0.22) : (optionMouse.containsMouse ? Theme.overlay(0.06) : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        Text {
                            id: optionLabel
                            anchors.centerIn: parent
                            text: optionBtn.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: optionBtn.isSelected ? Font.Bold : Font.Normal
                            color: optionBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: optionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: choiceRow.selected(optionBtn.modelData.value)
                        }
                    }
                }
            }
        }
    }
}
