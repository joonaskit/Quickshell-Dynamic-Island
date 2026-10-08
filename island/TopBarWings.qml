import ".."
import QtQuick
import Quickshell.Services.UPower

Item {
    id: root

    property bool isMaximized: false
    property string activeAppTitle: ""
    property date currentDate: new Date()
    property var displayBattery: UPower.displayDevice
    property real compactCenterWidth: Theme.compactWidthClock

    Behavior on compactCenterWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutCubic
        }
    }

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Theme.topMargin + Theme.compactHeight + Theme.px(6)

    // Bar visibility: visible when maximized or while fluidly growing/retracting
    visible: root.isMaximized || barBackground.width > (root.compactCenterWidth + 2)

    // Full-width continuous top bar background that grows fluidly from the center Island
    Rectangle {
        id: barBackground
        anchors.horizontalCenter: parent.horizontalCenter

        // Horizontal growth: expands from compact pill width to full screen width
        width: root.isMaximized ? root.width : root.compactCenterWidth

        // Vertical glide: moves smoothly from topMargin (10px) to top edge (0px)
        y: root.isMaximized ? 0 : Theme.topMargin

        // Height adjusts from compact pill height (38px) to top bar height (35px)
        height: root.isMaximized ? (Theme.topBarHeight + 1) : Theme.compactHeight

        // Radii: morphs from pill radius (19px) to flat (0px) as wings meet the display bezels
        topLeftRadius: root.isMaximized ? 0 : Theme.compactRadius
        topRightRadius: root.isMaximized ? 0 : Theme.compactRadius
        bottomLeftRadius: root.isMaximized ? 0 : Theme.compactRadius
        bottomRightRadius: root.isMaximized ? 0 : Theme.compactRadius

        color: Theme.islandBackground
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on topLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on topRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        // Ultra-sleek hairline border separating top bar from maximized application
        Rectangle {
            id: bottomHairline
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.overlay(0.12)
            opacity: (root.isMaximized && barBackground.width > root.width * 0.85) ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
        }
    }
}
