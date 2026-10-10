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

            // Top Header: Bluetooth Badge, Status, and Toggle Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                // Circular Bluetooth Badge
                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: BluetoothService.isEnabled ? Theme.accent : Theme.cardBackgroundHover

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "bluetooth"
                        size: Theme.px(19)
                        color: BluetoothService.isEnabled ? Theme.accentForeground : Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BluetoothService.togglePower();
                        }
                    }
                }

                // Title and Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Bluetooth"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(15)
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (!BluetoothService.isEnabled) return "Off";
                            if (BluetoothService.connectingMac !== "") return "Connecting...";
                            if (BluetoothService.connectedDevices.length > 0) {
                                return BluetoothService.connectedDevices[0].name;
                            }
                            return "Not Connected";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: (BluetoothService.isEnabled && BluetoothService.isConnected) ? Theme.accent : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Toggle switch
                Rectangle {
                    Layout.preferredWidth: Theme.px(46)
                    Layout.preferredHeight: Theme.px(26)
                    radius: Theme.px(13)
                    color: BluetoothService.isEnabled ? Theme.accentGreen : Theme.switchTrackOff

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    // Sliding Knob
                    Rectangle {
                        id: toggleKnob
                        y: Theme.px(2)
                        x: BluetoothService.isEnabled ? Theme.px(22) : Theme.px(2)
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
                            BluetoothService.togglePower();
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

            // Devices Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                opacity: BluetoothService.isEnabled ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                // Section Label
                Text {
                    text: "DEVICES"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                    Layout.fillWidth: true
                }

                // List of Paired Devices
                Column {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Repeater {
                        model: BluetoothService.pairedDevices.slice(0, 6)

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: Theme.px(34)
                            radius: Theme.corner(8)
                            color: deviceMouse.containsMouse ? Theme.cardBackgroundHover : (modelData.isConnected ? Theme.accentTint(0.12) : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(8)
                                anchors.rightMargin: Theme.px(8)
                                spacing: Theme.px(8)

                                // Device Icon (headphones or bluetooth)
                                SvgIcon {
                                    name: {
                                        let n = modelData.name.toLowerCase();
                                        if (n.includes("wh-") || n.includes("head") || n.includes("buds") || n.includes("ear") || n.includes("airpod")) {
                                            return "headphones";
                                        }
                                        return "bluetooth";
                                    }
                                    size: Theme.px(13)
                                    color: modelData.isConnected ? Theme.accent : Theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                                }

                                // Device Name
                                Text {
                                    text: modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.weight: modelData.isConnected ? Font.Bold : Font.Normal
                                    color: modelData.isConnected ? Theme.accent : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                                }

                                // Status text / checkmark
                                Text {
                                    text: {
                                        if (BluetoothService.connectingMac === modelData.mac) return "Connecting...";
                                        return modelData.isConnected ? "Connected" : "Not Connected";
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(10)
                                    color: modelData.isConnected ? Theme.accent : Theme.textTertiary
                                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                                }

                                SvgIcon {
                                    name: "check"
                                    size: Theme.px(12)
                                    color: Theme.accent
                                    opacity: modelData.isConnected ? 1.0 : 0.0
                                    scale: modelData.isConnected ? 1.0 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                                }
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    BluetoothService.toggleConnection(modelData.mac, modelData.isConnected);
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        width: parent.width
                        height: Theme.px(30)
                        opacity: BluetoothService.pairedDevices.length === 0 ? 1.0 : 0.0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "No paired devices"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            color: Theme.textTertiary
                        }
                    }
                }
            }

            // Message when Bluetooth is disabled
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(36)
                opacity: !BluetoothService.isEnabled ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                Text {
                    anchors.centerIn: parent
                    text: "Turn on Bluetooth to connect to devices"
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

            // Footer Link: Bluetooth Settings...
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
                        text: "Bluetooth Settings..."
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
                        BluetoothService.openSettings();
                        root.requestClose();
                    }
                }
            }
        }
    }
}
