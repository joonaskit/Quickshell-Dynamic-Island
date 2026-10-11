import "../.."
import QtQuick
import QtQuick.Layouts

// Move up / move down buttons for a row in a user-ordered list
RowLayout {
    id: moveButtons
    property bool canMoveUp: true
    property bool canMoveDown: true
    // delta is -1 for up, 1 for down
    signal moved(int delta)

    spacing: 2

    Repeater {
        model: [
            { "icon": "chevron-up", "delta": -1 },
            { "icon": "chevron-down", "delta": 1 }
        ]

        delegate: Rectangle {
            id: moveButton
            required property var modelData
            readonly property bool canMove: modelData.delta < 0 ? moveButtons.canMoveUp : moveButtons.canMoveDown

            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Theme.corner(7)
            color: moveMouse.pressed ? Theme.overlay(0.16) : (moveMouse.containsMouse ? Theme.overlay(0.1) : "transparent")
            opacity: canMove ? 1.0 : 0.25

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

            SvgIcon {
                anchors.centerIn: parent
                name: moveButton.modelData.icon
                size: 14
                color: Theme.textSecondary
            }

            MouseArea {
                id: moveMouse
                anchors.fill: parent
                enabled: moveButton.canMove
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: moveButtons.moved(moveButton.modelData.delta)
            }
        }
    }
}
