import ".."
import QtQuick

Item {
    id: root

    signal clicked()

    width: bubbleMouse.containsMouse ? Theme.px(44) : Theme.px(38)
    height: bubbleMouse.containsMouse ? Theme.px(44) : Theme.px(38)

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

    readonly property bool shouldShow: SettingsService.showDetachedNotifBubble && NotificationService.unreadCount > 0 && !isExpanded && !isTopBarMode

    scale: shouldShow ? 1.0 : 0.0
    opacity: shouldShow ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: Theme.animEntranceOvershoot
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
        width: bubbleBody.width + Theme.px(10)
        height: bubbleBody.height + Theme.px(8)
        radius: bubbleBody.radius + Theme.px(3)
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
            NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
        }

        SvgIcon {
            anchors.centerIn: parent
            name: SettingsService.dndEnabled ? "bell-off" : "bell"
            size: Theme.px(15)
            color: SettingsService.dndEnabled ? Theme.textTertiary : Theme.accentOrange
        }

        // Unread Badge Badge in Top Right
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.px(2)
            anchors.rightMargin: Theme.px(2)
            width: Math.max(Theme.px(14), badgeText.implicitWidth + Theme.px(6))
            height: Theme.px(14)
            radius: Theme.px(7)
            color: Theme.accentRed
            visible: NotificationService.unreadCount > 0

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: NotificationService.unreadCount > 9 ? "9+" : NotificationService.unreadCount
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(8)
                font.weight: Font.Bold
                color: Theme.onAccent
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
