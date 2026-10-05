import ".."
import QtQuick

Item {
    id: root

    property bool playing: false
    property color barColor: "#30d158"
    property real maxHeight: 15
    property real minHeight: 3
    property real barWidth: 3

    implicitWidth: 4 * barWidth + 3 * 2.5
    implicitHeight: maxHeight

    Row {
        anchors.centerIn: parent
        spacing: 2.5

        // Bar 1
        Rectangle {
            width: root.barWidth
            height: root.minHeight
            radius: root.barWidth / 2
            color: root.barColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: root.maxHeight * 0.85; duration: 320; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight * 1.5; duration: 280; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.maxHeight * 0.5; duration: 250; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight; duration: 300; easing.type: Easing.InOutQuad }
            }

            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
        }

        // Bar 2
        Rectangle {
            width: root.barWidth
            height: root.minHeight
            radius: root.barWidth / 2
            color: root.barColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: root.maxHeight * 0.4; duration: 260; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.maxHeight; duration: 350; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight * 1.8; duration: 290; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.maxHeight * 0.7; duration: 240; easing.type: Easing.InOutQuad }
            }

            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
        }

        // Bar 3
        Rectangle {
            width: root.barWidth
            height: root.minHeight
            radius: root.barWidth / 2
            color: root.barColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: root.maxHeight * 0.95; duration: 380; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight * 1.2; duration: 220; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.maxHeight * 0.65; duration: 310; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight; duration: 270; easing.type: Easing.InOutQuad }
            }

            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
        }

        // Bar 4
        Rectangle {
            width: root.barWidth
            height: root.minHeight
            radius: root.barWidth / 2
            color: root.barColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: root.maxHeight * 0.6; duration: 240; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.maxHeight * 0.9; duration: 330; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight * 2.0; duration: 280; easing.type: Easing.InOutQuad }
                NumberAnimation { to: root.minHeight; duration: 260; easing.type: Easing.InOutQuad }
            }

            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
        }
    }
}
