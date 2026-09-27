import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal clicked()

    width: bubbleMouse.containsMouse ? 44 : 38
    height: bubbleMouse.containsMouse ? 44 : 38

    Behavior on width {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Theme.animEasing
            easing.overshoot: Theme.animOvershoot
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Theme.animEasing
            easing.overshoot: Theme.animOvershoot
        }
    }

    property bool isExpanded: false
    property bool isTopBarMode: false

    readonly property bool shouldShow: NotificationService.unreadCount > 0 && !isExpanded && !isTopBarMode

    scale: shouldShow ? 1.0 : 0.0
    opacity: shouldShow ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationFast
        }
    }

    // Ambient drop shadow
    Rectangle {
        anchors.centerIn: bubbleBody
        width: bubbleBody.width + 10
        height: bubbleBody.height + 8
        radius: bubbleBody.radius + 3
        color: Theme.islandShadow
        opacity: 0.45
    }

    // OLED Black Bubble
    Rectangle {
        id: bubbleBody
        anchors.fill: parent
        radius: width / 2
        color: Theme.islandBackground
        border.width: 1
        border.color: Theme.islandBorder

        scale: bubbleMouse.pressed ? 0.90 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        SvgIcon {
            anchors.centerIn: parent
            name: "bell"
            size: 15
            color: Theme.accentOrange
        }

        // Unread Badge Badge in Top Right
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.rightMargin: 2
            width: Math.max(14, badgeText.implicitWidth + 6)
            height: 14
            radius: 7
            color: Theme.accentRed
            visible: NotificationService.unreadCount > 0

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: NotificationService.unreadCount > 9 ? "9+" : NotificationService.unreadCount
                font.family: Theme.fontDisplay
                font.pixelSize: 8
                font.weight: Font.Bold
                color: "#ffffff"
            }
        }

        MouseArea {
            id: bubbleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.clicked();
            }
        }
    }
}
