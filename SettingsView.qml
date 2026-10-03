import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestBack()
    signal requestClose()

    readonly property real maxAllowedHeight: {
        let scrH = (Screen.height > 0) ? Screen.height : 1080;
        return Math.min(scrH - Theme.px(120), Theme.px(840));
    }

    readonly property real desiredHeight: contentColumn.implicitHeight + bottomGrabberArea.height + Theme.px(28)
    readonly property bool needsScroll: desiredHeight > maxAllowedHeight

    implicitWidth: Theme.px(540)
    implicitHeight: Math.min(desiredHeight, maxAllowedHeight)

    // Smooth scrollable container
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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
                if (root.needsScroll) {
                    scrollContainer.contentY = Math.max(0, Math.min(scrollContainer.contentHeight - scrollContainer.height, scrollContainer.contentY - wheel.angleDelta.y));
                    scrollFadeTimer.restart();
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            width: scrollContainer.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 14

            // Top Header: Back Button, Title with Icon, and Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Back Button (returns to Expanded Island View)
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: backMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.08)
                    scale: backMouse.pressed ? 0.90 : (backMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "chevron-left"
                        size: 16
                        color: backMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestBack()
                    }
                }

                // Settings Icon & Title
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Qt.rgba(10/255, 132/255, 255/255, 0.22)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "settings"
                            size: 18
                            color: Theme.accentBlue
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Settings"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Preferences & Customization"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }
                }

                // Close Button (dismisses the island completely)
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.2) : "transparent"
                    scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
                        color: closeMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Section 0: Display & Scaling (DPI)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "DISPLAY & SCALING (DPI)"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Interface & Font Sizing"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: scalingCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: scalingCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. Interface Scale (DPI)
                        SettingSlider {
                            title: "Interface Scale (DPI)"
                            description: "Scale elements, islands, status bar pills, dock, and popup geometry (80% - 125%)"
                            iconName: "sliders"
                            iconColor: Theme.accentCyan
                            value: SettingsService.uiScale
                            minimumValue: 0.80
                            maximumValue: 1.25
                            stepSize: 0.05
                            presets: [
                                { label: "80%", value: 0.80 },
                                { label: "90%", value: 0.90 },
                                { label: "100% (Default)", value: 1.00 },
                                { label: "110%", value: 1.10 },
                                { label: "125%", value: 1.25 }
                            ]
                            onValueModified: function(val) {
                                SettingsService.setSetting("uiScale", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Text & Font Size Scale
                        SettingSlider {
                            title: "Text & Font Size"
                            description: "Proportionally scale clock digits, labels, titles, and text elements (85% - 125%)"
                            iconName: "type"
                            iconColor: Theme.accentYellow
                            value: SettingsService.fontScale
                            minimumValue: 0.85
                            maximumValue: 1.25
                            stepSize: 0.05
                            presets: [
                                { label: "85%", value: 0.85 },
                                { label: "90%", value: 0.90 },
                                { label: "100% (Default)", value: 1.00 },
                                { label: "110%", value: 1.10 },
                                { label: "125%", value: 1.25 }
                            ]
                            onValueModified: function(val) {
                                SettingsService.setSetting("fontScale", val);
                            }
                        }
                    }
                }
            }

            // Section 1: Window & Workspace Pills (Top Left)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "WINDOW & WORKSPACE PILLS"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Top Left Corner"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: windowPillsCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: windowPillsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. Window Controls Main Toggle
                        SettingToggle {
                            title: "Window Controls Pill"
                            description: "Display active application name, window title, and window actions menu"
                            iconName: "window"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showWindowControls
                            onToggled: function(val) {
                                SettingsService.setSetting("showWindowControls", val);
                            }
                        }

                        SettingDivider {}

                        // 1b. Auto-Hide Window Controls Sub-Toggle
                        SettingToggle {
                            title: "Auto-Hide Window Controls"
                            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
                            iconName: "chevron-up"
                            iconColor: Theme.accentBlue
                            isSubOption: true
                            enabled: SettingsService.showWindowControls
                            checked: SettingsService.autoHideWindowControls
                            onToggled: function(val) {
                                SettingsService.setSetting("autoHideWindowControls", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Virtual Desktops Main Toggle
                        SettingToggle {
                            title: "Virtual Desktops Pill"
                            description: "Display workspace switcher dots, desktop numbers, and quick workspace actions"
                            iconName: "desktop"
                            iconColor: Theme.accentPurple
                            checked: SettingsService.showVirtualDesktops
                            onToggled: function(val) {
                                SettingsService.setSetting("showVirtualDesktops", val);
                            }
                        }

                        SettingDivider {}

                        // 2b. Auto-Hide Virtual Desktops Sub-Toggle
                        SettingToggle {
                            title: "Auto-Hide Virtual Desktops"
                            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
                            iconName: "chevron-up"
                            iconColor: Theme.accentPurple
                            isSubOption: true
                            enabled: SettingsService.showVirtualDesktops
                            checked: SettingsService.autoHideVirtualDesktops
                            onToggled: function(val) {
                                SettingsService.setSetting("autoHideVirtualDesktops", val);
                            }
                        }
                    }
                }
            }

            // Section 2: Top Right Status Bar Icons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "STATUS BAR ICONS"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Top Right Cluster"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: statusIconsCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: statusIconsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. Caffeine
                        SettingToggle {
                            title: "Caffeine"
                            description: "Keep awake icon to prevent screen sleep and dimming"
                            iconName: "coffee"
                            iconColor: Theme.accentOrange
                            checked: SettingsService.showCaffeineIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showCaffeineIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Wi-Fi
                        SettingToggle {
                            title: "Wi-Fi & Network"
                            description: "Network connectivity status & quick Wi-Fi selection menu"
                            iconName: "wifi"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showWifiIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showWifiIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 3. Bluetooth
                        SettingToggle {
                            title: "Bluetooth"
                            description: "Bluetooth power state and quick paired devices list"
                            iconName: "bluetooth"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showBluetoothIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showBluetoothIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 4. Microphone
                        SettingToggle {
                            title: "Microphone"
                            description: "Input mute toggle & microphone volume control"
                            iconName: "mic"
                            iconColor: Theme.accentRed
                            checked: SettingsService.showMicIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showMicIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 5. Clipboard History
                        SettingToggle {
                            title: "Clipboard History"
                            description: "Quick clipboard search and copy history manager"
                            iconName: "clipboard"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showClipboardIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showClipboardIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 6. Performance Profiles
                        SettingToggle {
                            title: "Performance Profiles"
                            description: "Switch power profile between Power Saver, Balanced, and Performance"
                            iconName: "gauge"
                            iconColor: Theme.accentGreen
                            checked: SettingsService.showProfileIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showProfileIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 7. Hardware Monitor
                        SettingToggle {
                            title: "Hardware Monitor"
                            description: "Live CPU percentage & system resource statistics"
                            iconName: "cpu"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showHardwareIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showHardwareIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 8. Battery Indicator
                        SettingToggle {
                            title: "Battery Indicator"
                            description: "Display battery percentage widget & power menu"
                            iconName: "battery"
                            iconColor: Theme.accentGreen
                            checked: SettingsService.showBatteryIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showBatteryIcon", val);
                            }
                        }
                    }
                }
            }

            // Section 3: Dynamic Icons & Pinning
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "DYNAMIC ICONS & PINNING"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Auto-show or keep pinned"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dynamicIconsCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: dynamicIconsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. USB Devices Main Toggle
                        SettingToggle {
                            title: "USB & External Drives"
                            description: "Automatically shows when external drives or USB sticks are connected"
                            iconName: "usb"
                            iconColor: Theme.accentGreen
                            checked: SettingsService.showUsbIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showUsbIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 1b. Pin USB Toggle
                        SettingToggle {
                            title: "Always Show USB Icon (Pin)"
                            description: "Keep USB icon permanently visible even when no drives are plugged in"
                            iconName: "pin"
                            iconColor: Theme.accentGreen
                            isSubOption: true
                            enabled: SettingsService.showUsbIcon
                            checked: SettingsService.pinUsbIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("pinUsbIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Notifications Main Toggle
                        SettingToggle {
                            title: "Notification Bell"
                            description: "Automatically shows when unread or active notifications exist"
                            iconName: "bell"
                            iconColor: Theme.accentOrange
                            checked: SettingsService.showNotificationIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("showNotificationIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 2b. Pin Notification Toggle
                        SettingToggle {
                            title: "Always Show Notification Bell (Pin)"
                            description: "Keep bell permanently visible even when there are no unread notifications"
                            iconName: "pin"
                            iconColor: Theme.accentOrange
                            isSubOption: true
                            enabled: SettingsService.showNotificationIcon
                            checked: SettingsService.pinNotificationIcon
                            onToggled: function(val) {
                                SettingsService.setSetting("pinNotificationIcon", val);
                            }
                        }

                        SettingDivider {}

                        // 3. Background Apps Tray Pill Main Toggle
                        SettingToggle {
                            title: "Background Apps Tray Pill"
                            description: "Display persistent background application indicators and tray icons capsule"
                            iconName: "desktop"
                            iconColor: Theme.accentIndigo
                            checked: SettingsService.showAppTrayPill
                            onToggled: function(val) {
                                SettingsService.setSetting("showAppTrayPill", val);
                            }
                        }

                        SettingDivider {}

                        // 3b. Auto-Hide Tray Pill Sub-Toggle
                        SettingToggle {
                            title: "Auto-Hide Tray Pill"
                            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
                            iconName: "chevron-up"
                            iconColor: Theme.accentIndigo
                            isSubOption: true
                            enabled: SettingsService.showAppTrayPill
                            checked: SettingsService.autoHideAppTrayPill
                            onToggled: function(val) {
                                SettingsService.setSetting("autoHideAppTrayPill", val);
                            }
                        }

                        SettingDivider {}

                        // 4. Detached Notification Bubble Toggle
                        SettingToggle {
                            title: "Detached Notification Bubble"
                            description: "Secondary floating island circle displaying unread notification alerts"
                            iconName: "bell"
                            iconColor: Theme.accentOrange
                            checked: SettingsService.showDetachedNotifBubble
                            onToggled: function(val) {
                                SettingsService.setSetting("showDetachedNotifBubble", val);
                            }
                        }
                    }
                }
            }

            // Section 4: Clock & Time Settings
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "DATE & CLOCK"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: 4
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: clockCardCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: clockCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. 24-Hour Time Format
                        SettingToggle {
                            title: "24-Hour Time Format"
                            description: "Display clock in 24-hour mode instead of 12-hour AM/PM"
                            iconName: "clock"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.use24Hour
                            onToggled: function(val) {
                                SettingsService.setSetting("use24Hour", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Show Seconds
                        SettingToggle {
                            title: "Show Seconds in Expanded View"
                            description: "Display live seconds counter next to the time"
                            iconName: "clock"
                            iconColor: Theme.accentPurple
                            checked: SettingsService.showSeconds
                            onToggled: function(val) {
                                SettingsService.setSetting("showSeconds", val);
                            }
                        }
                    }
                }
            }

            // Section 5: Expanded Island Cards Customization
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "EXPANDED ISLAND CARDS"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Choose cards shown when expanded"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: expandedCardsCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: expandedCardsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. Mini Calendar
                        SettingToggle {
                            title: "Mini Calendar"
                            description: "Monthly calendar grid with current date highlight and week numbers"
                            iconName: "calendar"
                            iconColor: Theme.accentRed
                            checked: SettingsService.showExpandedCalendar
                            onToggled: function(val) {
                                SettingsService.setSetting("showExpandedCalendar", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Media Player
                        SettingToggle {
                            title: "Media Player"
                            description: "Playback controls, album artwork, track title, and interactive seek bar"
                            iconName: "music"
                            iconColor: Theme.accentRed
                            checked: SettingsService.showExpandedMedia
                            onToggled: function(val) {
                                SettingsService.setSetting("showExpandedMedia", val);
                            }
                        }

                        SettingDivider {}

                        // 3. Audio Output Selector
                        SettingToggle {
                            title: "Audio Output Selector"
                            description: "Quickly switch active audio playback device (speakers, headphones, HDMI)"
                            iconName: "headphones"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.showExpandedAudioSink
                            onToggled: function(val) {
                                SettingsService.setSetting("showExpandedAudioSink", val);
                            }
                        }

                        SettingDivider {}

                        // 4. Volume Slider
                        SettingToggle {
                            title: "Volume Slider"
                            description: "Interactive slider for master speaker output volume"
                            iconName: "volume-high"
                            iconColor: Theme.accentGreen
                            checked: SettingsService.showExpandedVolume
                            onToggled: function(val) {
                                SettingsService.setSetting("showExpandedVolume", val);
                            }
                        }

                        SettingDivider {}

                        // 5. Brightness Slider
                        SettingToggle {
                            title: "Brightness Slider"
                            description: "Interactive slider for screen backlight brightness"
                            iconName: "brightness-high"
                            iconColor: Theme.accentYellow
                            checked: SettingsService.showExpandedBrightness
                            onToggled: function(val) {
                                SettingsService.setSetting("showExpandedBrightness", val);
                            }
                        }
                    }
                }
            }

            // Section 6: Island Behavior & Timing
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    spacing: 6

                    Text {
                        text: "ISLAND BEHAVIOR & TIMING"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Text {
                        text: "• Morphing, full-screen & auto-collapse"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: islandCardCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: islandCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // 1. Show Media When Playing
                        SettingToggle {
                            title: "Show Media Playing in Compact Pill"
                            description: "Morphs compact pill into media status when music or audio is playing"
                            iconName: "music"
                            iconColor: Theme.accentRed
                            checked: SettingsService.showMediaWhenPlaying
                            onToggled: function(val) {
                                SettingsService.setSetting("showMediaWhenPlaying", val);
                            }
                        }

                        SettingDivider {}

                        // 2. Morph to Top Bar When Maximized
                        SettingToggle {
                            title: "Morph to Top Bar When Windows Maximized"
                            description: "Liquidly flattens the island into a full-width GNOME-style top bar"
                            iconName: "window"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.morphToTopBarWhenMaximized
                            onToggled: function(val) {
                                SettingsService.setSetting("morphToTopBarWhenMaximized", val);
                            }
                        }

                        SettingDivider {}

                        // 2b. Reserve Space When Maximized Sub-Toggle
                        SettingToggle {
                            title: "Reserve Top Bar Space When Maximized"
                            description: "Reserves screen space so maximized windows sit underneath the top bar"
                            iconName: "maximize"
                            iconColor: Theme.accentCyan
                            isSubOption: true
                            enabled: SettingsService.morphToTopBarWhenMaximized
                            checked: SettingsService.reserveSpaceWhenMaximized
                            onToggled: function(val) {
                                SettingsService.setSetting("reserveSpaceWhenMaximized", val);
                            }
                        }

                        SettingDivider {}

                        // 3. Auto-Hide Island on Fullscreen
                        SettingToggle {
                            title: "Auto-Hide Island on Fullscreen"
                            description: "Collapses and completely hides the Island when games or fullscreen apps are active"
                            iconName: "desktop"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.hideOnFullscreen
                            onToggled: function(val) {
                                SettingsService.setSetting("hideOnFullscreen", val);
                            }
                        }

                        SettingDivider {}

                        // 4. Auto-Collapse Timeout Segmented Picker
                        SettingSegmented {
                            title: "Auto-Collapse Inactivity Timeout"
                            description: "Duration before expanded island automatically collapses when mouse is idle"
                            iconName: "clock"
                            iconColor: Theme.accentPurple
                            currentValue: SettingsService.autoCollapseTimeout
                            options: [
                                { "label": "3s", "value": 3000 },
                                { "label": "6s", "value": 6000 },
                                { "label": "10s", "value": 10000 },
                                { "label": "Never", "value": 0 }
                            ]
                            onSelected: function(val) {
                                SettingsService.setSetting("autoCollapseTimeout", val);
                            }
                        }
                    }
                }
            }

            // Section 7: Dock Behavior
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "DOCK"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: 4
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dockCardCol.implicitHeight
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    ColumnLayout {
                        id: dockCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        SettingToggle {
                            title: "Auto-Hide Dock on Fullscreen"
                            description: "Automatically hides the bottom dock when games or fullscreen apps are active"
                            iconName: "desktop"
                            iconColor: Theme.accentBlue
                            checked: SettingsService.dockAutoHideOnFullscreen
                            onToggled: function(val) {
                                SettingsService.setSetting("dockAutoHideOnFullscreen", val);
                            }
                        }
                    }
                }
            }

            // Section 8: Persistence Information & Reset
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: persistCol.implicitHeight + 20
                radius: 14
                color: Qt.rgba(0, 0, 0, 0.3)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    id: persistCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.accentGreen
                        }

                        Text {
                            text: "Settings saved to: " + SettingsService.settingsFilePath
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        // Reset Button
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: resetRow.implicitWidth + 14
                            radius: 12
                            color: resetMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                            RowLayout {
                                id: resetRow
                                anchors.centerIn: parent
                                spacing: 4

                                SvgIcon {
                                    name: "refresh"
                                    size: 11
                                    color: resetMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                                }

                                Text {
                                    text: "Reset Defaults"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: resetMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.resetDefaults()
                            }
                        }
                    }
                }
            }
        }
    }

    // Subtle Subtle fading scroll indicator (anchored strictly to card viewport, hidden when idle)
    Item {
        id: scrollTrack
        anchors.top: scrollContainer.top
        anchors.topMargin: 46
        anchors.bottom: scrollContainer.bottom
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        width: 3
        visible: root.needsScroll
        opacity: (scrollContainer.moving || scrollContainer.flicking || scrollFadeTimer.running) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }

        Rectangle {
            id: scrollThumb
            width: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.35)
            y: Math.max(0, Math.min(scrollTrack.height - height, scrollContainer.visibleArea.yPosition * scrollTrack.height))
            height: Math.max(28, scrollContainer.visibleArea.heightRatio * scrollTrack.height)
        }
    }

    Timer {
        id: scrollFadeTimer
        interval: 800
        repeat: false
    }

    // Bottom Grabber Pill
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

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        }

        MouseArea {
            id: grabberMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestClose()
        }
    }

    // Reusable Hairline Divider between settings items
    component SettingDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    // Inline Reusable SettingToggle component
    component SettingToggle: Rectangle {
        id: toggleRow
        property string title: ""
        property string description: ""
        property string iconName: ""
        property color iconColor: Theme.accentBlue
        property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
        property bool checked: false
        property bool isSubOption: false
        signal toggled(bool val)

        Layout.fillWidth: true
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

    // Inline Reusable SettingSegmented component (Segmented segmented picker)
    component SettingSegmented: Rectangle {
        id: segRow
        property string title: ""
        property string description: ""
        property string iconName: ""
        property color iconColor: Theme.accentBlue
        property color iconBadgeColor: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.18)
        property var options: []
        property var currentValue: null
        property bool isSubOption: false
        signal selected(var val)

        Layout.fillWidth: true
        implicitHeight: segCol.implicitHeight + 20
        color: "transparent"
        opacity: enabled ? 1.0 : 0.4

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationPopover }
        }

        ColumnLayout {
            id: segCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: segRow.isSubOption ? 28 : 12
            anchors.rightMargin: 12
            anchors.topMargin: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Icon Badge
                Rectangle {
                    visible: segRow.iconName !== ""
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 7
                    color: segRow.iconBadgeColor

                    SvgIcon {
                        anchors.centerIn: parent
                        name: segRow.iconName
                        size: 14
                        color: segRow.iconColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: segRow.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        id: segDescText
                        text: segRow.description
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textSecondary
                        visible: text !== ""
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Segmented Picker Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: segRow.options

                        Rectangle {
                            id: segOptionBtn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            readonly property bool isSelected: segRow.currentValue === modelData.value
                            color: isSelected ? Qt.rgba(1, 1, 1, 0.22) : (segBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: segOptionBtn.isSelected ? Font.Bold : Font.Normal
                                color: segOptionBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                id: segBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    segRow.selected(modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Reusable Custom Draggable Slider Row with live percentage badge and quick presets
    component SettingSlider: Rectangle {
        id: sliderRow
        Layout.fillWidth: true
        implicitHeight: sliderCol.implicitHeight + 20
        color: "transparent"

        property string title: ""
        property string description: ""
        property string iconName: "sliders"
        property color iconColor: Theme.accentCyan
        property real value: 1.0
        property real minimumValue: 0.8
        property real maximumValue: 1.25
        property real stepSize: 0.05
        property var presets: []

        signal valueModified(real newValue)

        readonly property real fraction: Math.max(0.0, Math.min(1.0, (value - minimumValue) / (maximumValue - minimumValue)))

        function updateFromPos(mouseX, trackWidth) {
            if (trackWidth <= 0) return;
            let ratio = Math.max(0.0, Math.min(1.0, mouseX / trackWidth));
            let rawVal = minimumValue + ratio * (maximumValue - minimumValue);
            let stepped = Math.round(rawVal / stepSize) * stepSize;
            let finalVal = Math.max(minimumValue, Math.min(maximumValue, Math.round(stepped * 100) / 100));
            sliderRow.valueModified(finalVal);
        }

        ColumnLayout {
            id: sliderCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            // Header Row: Icon, Title & Live Value Badge
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 7
                    color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.16)

                    SvgIcon {
                        anchors.centerIn: parent
                        name: sliderRow.iconName
                        size: 14
                        color: sliderRow.iconColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: sliderRow.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                    }

                    Text {
                        text: sliderRow.description
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        Layout.maximumWidth: 340
                        wrapMode: Text.WordWrap
                    }
                }

                // Live Percentage Badge
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 24
                    radius: 12
                    color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(sliderRow.value * 100) + "%"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: sliderRow.iconColor
                    }
                }
            }

            // Draggable Slider Track
            Item {
                id: trackArea
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                // Background Rail
                Rectangle {
                    id: railBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)

                    // Active Fill Track
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(radius * 2, trackArea.width * sliderRow.fraction)
                        radius: 3
                        color: sliderRow.iconColor

                        Behavior on width {
                            enabled: !trackMouse.pressed
                            NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Draggable Knob / Thumb
                Rectangle {
                    id: thumb
                    width: 18
                    height: 18
                    radius: 9
                    color: "#ffffff"
                    x: Math.max(0, Math.min(trackArea.width - width, (trackArea.width * sliderRow.fraction) - (width / 2)))
                    anchors.verticalCenter: parent.verticalCenter
                    scale: trackMouse.pressed ? 1.15 : (trackMouse.containsMouse ? 1.08 : 1.0)

                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.25)

                    Behavior on x {
                        enabled: !trackMouse.pressed
                        NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                    }

                    // Subtle inner glow / shadow
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: sliderRow.iconColor
                        opacity: trackMouse.pressed ? 0.9 : 0.4

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animDurationFast }
                        }
                    }
                }

                MouseArea {
                    id: trackMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: function(mouse) {
                        sliderRow.updateFromPos(mouse.x + 4, trackArea.width);
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            sliderRow.updateFromPos(mouse.x + 4, trackArea.width);
                        }
                    }
                }
            }

            // Quick Preset Buttons Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: sliderRow.presets && sliderRow.presets.length > 0

                Repeater {
                    model: sliderRow.presets

                    Rectangle {
                        id: presetBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 6
                        readonly property bool isSelected: Math.abs(sliderRow.value - modelData.value) < 0.02
                        color: isSelected ? Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.25) : (presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? sliderRow.iconColor : "transparent"
                        scale: presetMouse.pressed ? 0.94 : (presetMouse.containsMouse ? 1.04 : 1.0)

                        Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }
                        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: presetBtn.isSelected ? Font.Bold : Font.Normal
                            color: presetBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sliderRow.valueModified(modelData.value);
                            }
                        }
                    }
                }
            }
        }
    }
}

