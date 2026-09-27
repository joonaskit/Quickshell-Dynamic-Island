import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : 340) : 310
    implicitHeight: mainCard.height

    // Soft Drop Shadow
    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + 16
        height: mainCard.height + 12
        radius: mainCard.radius + 4
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    // Main Control Center Card
    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? 14 : 28)
        radius: root.embedded ? 0 : 18
        color: root.embedded ? "transparent" : "#1c1c1e"
        border.width: root.embedded ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? 10 : 14
            spacing: 12

            // Top Header: Bluetooth Badge, Status, and iOS Switch Toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Circular Bluetooth Badge
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: BluetoothService.isEnabled ? Theme.accentBlue : "#2c2c2e"

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "bluetooth"
                        size: 19
                        color: "#ffffff"
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
                    spacing: 2

                    Text {
                        text: "Bluetooth"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 15
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
                        font.pixelSize: 11
                        color: (BluetoothService.isEnabled && BluetoothService.isConnected) ? Theme.accentBlue : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Apple iOS Switch
                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 26
                    radius: 13
                    color: BluetoothService.isEnabled ? Theme.accentGreen : "#39393d"

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    // Sliding Knob
                    Rectangle {
                        id: toggleKnob
                        y: 2
                        x: BluetoothService.isEnabled ? 22 : 2
                        width: 22
                        height: 22
                        radius: 11
                        color: "#ffffff"

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
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Devices Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: BluetoothService.isEnabled

                // Section Label
                Text {
                    text: "DEVICES"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                    Layout.fillWidth: true
                }

                // List of Paired Devices
                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: BluetoothService.pairedDevices.slice(0, 6)

                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 34
                            radius: 8
                            color: deviceMouse.containsMouse ? Theme.cardBackgroundHover : (modelData.isConnected ? Qt.rgba(10/255, 132/255, 255/255, 0.12) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Device Icon (headphones or bluetooth)
                                SvgIcon {
                                    name: {
                                        let n = modelData.name.toLowerCase();
                                        if (n.includes("wh-") || n.includes("head") || n.includes("buds") || n.includes("ear") || n.includes("airpod")) {
                                            return "headphones";
                                        }
                                        return "bluetooth";
                                    }
                                    size: 13
                                    color: modelData.isConnected ? Theme.accentBlue : Theme.textSecondary
                                }

                                // Device Name
                                Text {
                                    text: modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: modelData.isConnected ? Font.Bold : Font.Normal
                                    color: modelData.isConnected ? Theme.accentBlue : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Status text / checkmark
                                Text {
                                    text: {
                                        if (BluetoothService.connectingMac === modelData.mac) return "Connecting...";
                                        return modelData.isConnected ? "Connected" : "Not Connected";
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: modelData.isConnected ? Theme.accentBlue : Theme.textTertiary
                                }

                                SvgIcon {
                                    name: "check"
                                    size: 12
                                    color: Theme.accentBlue
                                    visible: modelData.isConnected
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
                        height: 30
                        visible: BluetoothService.pairedDevices.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: "No paired devices"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textTertiary
                        }
                    }
                }
            }

            // Message when Bluetooth is disabled
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                visible: !BluetoothService.isEnabled

                Text {
                    anchors.centerIn: parent
                    text: "Turn on Bluetooth to connect to devices"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textTertiary
                }
            }

            // Divider before Settings
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Footer Link: Bluetooth Settings...
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 8
                color: settingsMouse.containsMouse ? Theme.cardBackgroundHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    Text {
                        text: "Bluetooth Settings..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }

                    SvgIcon {
                        name: "chevron-right"
                        size: 12
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
