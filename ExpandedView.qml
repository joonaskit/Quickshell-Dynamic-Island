import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Item {
    id: root

    property date currentTime: new Date()
    property var player: null
    property var displayBattery: null

    signal requestCollapse()
    signal requestOpenSettings()

    // Card visibility bindings directly referenced from services to avoid layout cycle / forward reference errors
    readonly property bool showCalendar: SettingsService.showExpandedCalendar
    readonly property bool showMedia: SettingsService.showExpandedMedia && (root.player !== null)
    readonly property bool showNotifications: SettingsService.showExpandedNotifications && NotificationService.notifications.length > 0
    readonly property bool showAudioSink: SettingsService.showExpandedAudioSink
    readonly property bool showVolume: SettingsService.showExpandedVolume
    readonly property bool showBrightness: SettingsService.showExpandedBrightness && BrightnessService.isAvailable
    readonly property bool showControls: showAudioSink || showVolume || showBrightness

    // Screen-aware maximum height to prevent overflowing the monitor or window
    readonly property real maxAllowedHeight: {
        let scrH = (Screen.height > 0) ? Screen.height : 1080;
        return Math.min(scrH - Theme.px(120), Theme.px(840));
    }

    readonly property real desiredHeight: contentColumn.implicitHeight + bottomGrabberArea.height + Theme.px(24)
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
            width: scrollContainer.width - Theme.px(28)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.px(14)
            spacing: Theme.px(12)

            // Top Header: Centered Clock & Date with Settings Button
            Item {
                Layout.fillWidth: true
                implicitHeight: clockCol.implicitHeight

                ColumnLayout {
                    id: clockCol
                    anchors.centerIn: parent
                    spacing: Theme.px(2)

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.px(4)

                        Text {
                            text: {
                                if (Theme.use24Hour) {
                                    return Qt.formatDateTime(root.currentTime, "hh:mm");
                                } else {
                                    return Qt.formatDateTime(root.currentTime, "h:mm");
                                }
                            }
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontPx(24)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Theme.textPrimary
                        }

                        Text {
                            text: ":" + Qt.formatDateTime(root.currentTime, "ss")
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontPx(15)
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignBaseline
                            visible: Theme.showSeconds
                        }

                        Text {
                            text: Qt.formatDateTime(root.currentTime, "AP")
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontPx(12)
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
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                // Settings Icon Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(30)
                    height: Theme.px(30)
                    radius: Theme.px(15)
                    color: settingsMouse.pressed ? Qt.rgba(1, 1, 1, 0.16) : (settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                    scale: settingsMouse.pressed ? 0.92 : (settingsMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutBack } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "settings"
                        size: Theme.px(15)
                        color: settingsMouse.containsMouse ? Theme.accentBlue : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.requestOpenSettings();
                        }
                    }
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
                id: calendarWidget
                Layout.fillWidth: true
                currentDate: root.currentTime
                visible: root.showCalendar
            }

            // Hairline Divider after calendar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: root.showCalendar && (root.showMedia || root.showNotifications || root.showControls)
            }

            // Media Player Section
            MediaWidget {
                id: mediaWidget
                Layout.fillWidth: true
                player: root.player
                visible: root.showMedia
            }

            // Divider between Media and following content
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: root.showMedia && (root.showNotifications || root.showControls)
            }

            // Notification List Section (visible when enabled and there are notifications)
            NotificationListView {
                id: notificationList
                Layout.fillWidth: true
                visible: root.showNotifications
            }

            // Divider after notifications
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: root.showNotifications && root.showControls
            }

            // System Controls Section (Audio Output, Volume & Brightness)
            ColumnLayout {
                id: controlsCol
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: root.showControls

                AudioOutputSelector {
                    id: audioOutputSelector
                    Layout.fillWidth: true
                    visible: root.showAudioSink
                }

                VolumeSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    visible: root.showVolume
                }

                BrightnessSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    visible: root.showBrightness
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
        height: Theme.px(20)

        Rectangle {
            anchors.centerIn: parent
            width: Theme.px(38)
            height: Theme.px(4)
            radius: Theme.px(2)
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
