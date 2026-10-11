import "../.."
import QtQuick
import QtQuick.Layouts

// Row of a user-ordered list: icon, title and move up / down buttons
Item {
    id: orderRow
    property string title: ""
    property string iconName: ""
    property color iconColor: Theme.accentBlue
    // False dims the row, for an entry that is currently turned off
    property bool active: true
    property alias canMoveUp: moveButtons.canMoveUp
    property alias canMoveDown: moveButtons.canMoveDown
    signal moved(int delta)

    readonly property bool matchesSearch: SettingsSearch.matches(title, "")

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: 38

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: Theme.corner(7)
            color: Qt.rgba(orderRow.iconColor.r, orderRow.iconColor.g, orderRow.iconColor.b, 0.18)
            opacity: orderRow.active ? 1.0 : 0.4

            SvgIcon {
                anchors.centerIn: parent
                name: orderRow.iconName
                size: 14
                color: orderRow.iconColor
            }
        }

        Text {
            Layout.fillWidth: true
            text: orderRow.active ? orderRow.title : orderRow.title + " (off)"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.textPrimary
            opacity: orderRow.active ? 1.0 : 0.4
            elide: Text.ElideRight
        }

        SettingMoveButtons {
            id: moveButtons
            visible: !SettingsSearch.active
            onMoved: function(delta) { orderRow.moved(delta); }
        }
    }
}
