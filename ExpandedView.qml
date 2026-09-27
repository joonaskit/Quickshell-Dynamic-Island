import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Item {
    id: root

    property date currentTime: new Date()
    property var player: null
    property var displayBattery: null

    signal requestCollapse()

    // Screen-aware maximum height to prevent overflowing the monitor or window
    readonly property real maxAllowedHeight: {
        let scrH = (Screen.height > 0) ? Screen.height : 1080;
        return Math.min(scrH - 120, 840);
    }

    readonly property real desiredHeight: contentColumn.implicitHeight + bottomGrabberArea.height + 24
    readonly property bool needsScroll: desiredHeight > maxAllowedHeight

    implicitWidth: Theme.expandedWidth
    implicitHeight: Math.min(desiredHeight, maxAllowedHeight)

    // Background click-to-close area: clicking the black background dismisses the expanded pill
    MouseArea {
        id: backgroundClickArea
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: {
            root.requestCollapse();
        }
    }

    // Smooth scrollable container if content exceeds maxAllowedHeight
    Flickable {
        id: scrollContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomGrabberArea.top
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.needsScroll

        // Mouse wheel scrolling support
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
                if (root.needsScroll) {
                    scrollContainer.contentY = Math.max(0, Math.min(scrollContainer.contentHeight - scrollContainer.height, scrollContainer.contentY - wheel.angleDelta.y));
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            width: scrollContainer.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 12

            // Top Header: Centered Clock & Date
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: {
                            if (Theme.use24Hour) {
                                return Qt.formatDateTime(root.currentTime, "hh:mm");
                            } else {
                                return Qt.formatDateTime(root.currentTime, "h:mm");
                            }
                        }
                        font.family: Theme.fontDisplay
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        color: Theme.textPrimary
                    }

                    Text {
                        text: ":" + Qt.formatDateTime(root.currentTime, "ss")
                        font.family: Theme.fontDisplay
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignBaseline
                        visible: Theme.showSeconds
                    }

                    Text {
                        text: Qt.formatDateTime(root.currentTime, "AP")
                        font.family: Theme.fontDisplay
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignBaseline
                        visible: !Theme.use24Hour
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.textSecondary
                }
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Mini Calendar Widget with week numbers
            MiniCalendarWidget {
                Layout.fillWidth: true
                currentDate: root.currentTime
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Media Player Section
            MediaWidget {
                id: mediaWidget
                Layout.fillWidth: true
                player: root.player
                visible: root.player !== null
            }

            // Divider between Media and Sliders if media is active
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: root.player !== null
            }

            // Notification List Section (visible when there are notifications)
            NotificationListView {
                Layout.fillWidth: true
                visible: NotificationService.notifications.length > 0
            }

            // Divider after notifications
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: NotificationService.notifications.length > 0
            }

            // System Controls Section (Audio Output, Volume & Brightness)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                AudioOutputSelector {
                    Layout.fillWidth: true
                }

                VolumeSlider {
                    Layout.fillWidth: true
                }

                BrightnessSlider {
                    Layout.fillWidth: true
                    visible: BrightnessService.isAvailable
                }
            }
        }
    }

    // Always-visible Bottom Grabber Pill right above the rounded bottom border
    Item {
        id: bottomGrabberArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20

        Rectangle {
            anchors.centerIn: parent
            width: 38
            height: 4
            radius: 2
            color: grabberMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.25)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        MouseArea {
            id: grabberMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.requestCollapse();
            }
        }
    }
}
