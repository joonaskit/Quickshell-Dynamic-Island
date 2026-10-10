import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : Theme.px(340)) : Theme.px(310)
    implicitHeight: mainCard.height

    // Soft Drop Shadow
    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + Theme.px(16)
        height: mainCard.height + Theme.px(12)
        radius: mainCard.radius + Theme.px(4)
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    // Main Control Center Card
    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? Theme.px(14) : Theme.px(28))
        radius: root.embedded ? 0 : Theme.px(18)
        color: root.embedded ? "transparent" : Theme.cardBackground
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? Theme.px(10) : Theme.px(14)
            spacing: Theme.px(12)

            // Top Header: Wi-Fi Badge, Status, and Toggle Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                // Circular Wi-Fi Badge
                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: NetworkService.isWifiEnabled ? Theme.accent : Theme.cardBackgroundHover

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "wifi"
                        size: Theme.px(19)
                        color: NetworkService.isWifiEnabled ? Theme.accentForeground : Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NetworkService.toggleWifi();
                        }
                    }
                }

                // Title and Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Wi-Fi"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(15)
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (!NetworkService.isWifiEnabled) return "Off";
                            if (NetworkService.connectingSsid !== "") return "Connecting to " + NetworkService.connectingSsid + "...";
                            if (NetworkService.isConnected && NetworkService.isWifi) return NetworkService.ssid;
                            return "Not Connected";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: (NetworkService.isWifiEnabled && NetworkService.isConnected) ? Theme.accent : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Toggle switch
                Rectangle {
                    Layout.preferredWidth: Theme.px(46)
                    Layout.preferredHeight: Theme.px(26)
                    radius: Theme.px(13)
                    color: NetworkService.isWifiEnabled ? Theme.accentGreen : Theme.switchTrackOff

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    // Sliding Knob
                    Rectangle {
                        id: toggleKnob
                        y: Theme.px(2)
                        x: NetworkService.isWifiEnabled ? Theme.px(22) : Theme.px(2)
                        width: Theme.px(22)
                        height: Theme.px(22)
                        radius: Theme.px(11)
                        color: Theme.sliderHandle

                        Behavior on x {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NetworkService.toggleWifi();
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Available Networks Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: NetworkService.isWifiEnabled

                // Section Label & Refresh button
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "AVAILABLE NETWORKS"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                        Layout.fillWidth: true
                    }

                    // Refresh Button
                    Rectangle {
                        Layout.preferredWidth: Theme.px(20)
                        Layout.preferredHeight: Theme.px(20)
                        radius: Theme.px(10)
                        color: refreshMouse.containsMouse ? Theme.cardBackgroundHover : "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: Theme.px(11)
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NetworkService.scanWifi();
                            }
                        }
                    }
                }

                // List of Networks
                Column {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Repeater {
                        model: NetworkService.availableNetworks.slice(0, 6)

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: Theme.px(32)
                            radius: Theme.corner(8)
                            color: itemMouse.containsMouse ? Theme.cardBackgroundHover : (modelData.inUse ? Theme.accentTint(0.12) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(8)
                                anchors.rightMargin: Theme.px(8)
                                spacing: Theme.px(8)

                                // Checkmark if connected
                                SvgIcon {
                                    name: "check"
                                    size: Theme.px(12)
                                    color: Theme.accent
                                    opacity: modelData.inUse ? 1.0 : 0.0
                                    scale: modelData.inUse ? 1.0 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                                }

                                // Network Name
                                Text {
                                    text: modelData.ssid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.weight: modelData.inUse ? Font.Bold : Font.Normal
                                    color: modelData.inUse ? Theme.accent : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Lock icon if secured
                                SvgIcon {
                                    name: "lock"
                                    size: Theme.px(11)
                                    color: Theme.textTertiary
                                    visible: modelData.isSecure
                                }

                                // Wi-Fi Signal
                                SvgIcon {
                                    name: "wifi"
                                    size: Theme.px(12)
                                    color: modelData.inUse ? Theme.accent : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!modelData.inUse) {
                                        NetworkService.connectTo(modelData.ssid);
                                    }
                                }
                            }
                        }
                    }

                    // Empty / Scanning state
                    Item {
                        width: parent.width
                        height: Theme.px(30)
                        opacity: NetworkService.availableNetworks.length === 0 ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: NetworkService.isScanning ? "Scanning for networks..." : "No networks found"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            color: Theme.textTertiary
                        }
                    }
                }
            }

            // Message when Wi-Fi is disabled
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(36)
                opacity: !NetworkService.isWifiEnabled ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                Text {
                    anchors.centerIn: parent
                    text: "Turn on Wi-Fi to see available networks"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    color: Theme.textTertiary
                }
            }

            // Divider before Settings
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Footer Link: Wi-Fi Settings...
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(28)
                radius: Theme.corner(8)
                color: settingsMouse.containsMouse ? Theme.cardBackgroundHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(8)
                    anchors.rightMargin: Theme.px(8)

                    Text {
                        text: "Wi-Fi Settings..."
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }

                    SvgIcon {
                        name: "chevron-right"
                        size: Theme.px(12)
                        color: Theme.textTertiary
                    }
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NetworkService.openSettings();
                        root.requestClose();
                    }
                }
            }
        }
    }
}
