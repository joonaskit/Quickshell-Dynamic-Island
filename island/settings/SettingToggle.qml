import "../.."
import QtQuick
import QtQuick.Layouts

// Inline Reusable SettingToggle component
Rectangle {
    id: toggleRow
    property string title: ""
    property string description: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
    property bool checked: false
    property bool isSubOption: false
    signal toggled(bool val)

    readonly property bool matchesSearch: SettingsSearch.matches(title, description)

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: descText.text !== "" ? 52 : 42
    color: rowMouse.containsMouse && enabled ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
    radius: 10
    opacity: enabled ? 1.0 : 0.4

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationPopover }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: toggleRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (toggleRow.enabled) {
                toggleRow.toggled(!toggleRow.checked);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: toggleRow.isSubOption ? 28 : 12
        anchors.rightMargin: 12
        spacing: 10

        // Icon Badge
        Rectangle {
            visible: toggleRow.iconName !== ""
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 7
            color: toggleRow.iconBadgeColor

            SvgIcon {
                anchors.centerIn: parent
                name: toggleRow.iconName
                size: 14
                color: toggleRow.iconColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: toggleRow.title
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                id: descText
                text: toggleRow.description
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
                visible: text !== ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Toggle switch
        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            radius: 12
            color: toggleRow.checked ? Theme.accentGreen : "#39393d"

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

            Rectangle {
                y: 2
                x: toggleRow.checked ? 22 : 2
                width: 20
                height: 20
                radius: 10
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
