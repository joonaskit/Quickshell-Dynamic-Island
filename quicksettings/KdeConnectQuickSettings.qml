import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    readonly property var device: KdeConnectService.device
    readonly property bool ready: device !== null && device.reachable
    readonly property color kcColor: Theme.accentGreen

    implicitWidth: embedded ? (parent ? parent.width : Theme.px(340)) : Theme.px(320)
    implicitHeight: mainCard.height

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

    // Action button with an icon and a label. Inline components cannot see this file's ids, so they use Theme directly
    component ActionButton: Rectangle {
        id: button

        property string text: ""
        property string iconName: ""
        property bool active: true
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.px(34)
        radius: Theme.px(17)
        color: !active ? Theme.overlay(0.04) : (buttonMouse.containsMouse ? Theme.accentTint(0.3) : Theme.overlay(0.1))
        scale: buttonMouse.pressed && active ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.px(6)
            opacity: button.active ? 1.0 : 0.4

            SvgIcon {
                name: button.iconName
                size: Theme.px(13)
                color: Theme.textPrimary
            }

            Text {
                text: button.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.Bold
                color: Theme.textPrimary
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (button.active) button.clicked()
        }
    }

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

            // Header: badge, device name and connection state
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: root.ready ? Qt.rgba(48/255, 209/255, 88/255, 0.22) : Theme.cardBackgroundHover
                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "phone"
                        size: Theme.px(20)
                        color: root.ready ? root.kcColor : Theme.textTertiary
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: root.device ? root.device.name : "KDE Connect"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!KdeConnectService.daemonAvailable) return "KDE Connect is not running";
                            if (!root.device) return "No paired devices";
                            if (!root.device.reachable) return "Not connected. Open KDE Connect on the phone";
                            if (root.device.hasBattery) return "Connected, battery " + root.device.charge + "%" + (root.device.charging ? " (charging)" : "");
                            return "Connected";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: root.ready ? root.kcColor : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Device picker when more than one is paired
            Flow {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: KdeConnectService.devices.length > 1

                Repeater {
                    model: KdeConnectService.devices

                    Rectangle {
                        readonly property bool selected: root.device !== null && modelData.id === root.device.id

                        width: chipLabel.implicitWidth + Theme.px(20)
                        height: Theme.px(24)
                        radius: Theme.px(12)
                        color: selected ? Qt.rgba(48/255, 209/255, 88/255, 0.22) : (chipMouse.containsMouse ? Theme.overlay(0.1) : Theme.overlay(0.05))
                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: selected ? Font.Bold : Font.Normal
                            color: modelData.reachable ? (selected ? root.kcColor : Theme.textSecondary) : Theme.textTertiary
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: KdeConnectService.selectDevice(modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
                visible: root.device !== null
            }

            // Actions the connected device supports
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.px(8)
                rowSpacing: Theme.px(8)
                visible: root.device !== null

                ActionButton {
                    text: "PING"
                    iconName: "bell"
                    active: root.ready && root.device.canPing
                    onClicked: KdeConnectService.ping(root.device.id)
                }

                ActionButton {
                    text: "SEND CLIPBOARD"
                    iconName: "clipboard"
                    active: root.ready && root.device.canClipboard
                    onClicked: KdeConnectService.sendClipboard(root.device.id)
                }

                ActionButton {
                    text: "SEND FILE"
                    iconName: "folder"
                    active: root.ready && root.device.canShare
                    onClicked: KdeConnectService.pickAndShare(root.device.id)
                }

                ActionButton {
                    text: "FIND PHONE"
                    iconName: "phone"
                    active: root.ready && root.device.canRing
                    onClicked: KdeConnectService.ring(root.device.id)
                }
            }

            // Send text or a link
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)
                visible: root.ready && root.device.canShare

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(30)
                    radius: Theme.corner(8)
                    color: Theme.overlay(0.05)
                    border.width: 1
                    border.color: shareInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                    TextInput {
                        id: shareInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(10)
                        anchors.rightMargin: Theme.px(10)
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                        color: Theme.textPrimary
                        selectionColor: Theme.accentTint(0.4)
                        selectedTextColor: Theme.textPrimary
                        clip: true
                        selectByMouse: true

                        function send() {
                            KdeConnectService.shareText(root.device.id, text);
                            text = "";
                        }
                        onAccepted: send()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: shareInput.text === ""
                            text: "Send text or a link"
                            font: shareInput.font
                            color: Theme.textTertiary
                        }
                    }
                }

                Rectangle {
                    Layout.preferredHeight: Theme.px(28)
                    Layout.preferredWidth: sendLabel.implicitWidth + Theme.px(24)
                    radius: Theme.px(14)
                    color: sendMouse.containsMouse ? Theme.accentTint(0.3) : Theme.overlay(0.1)
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    Text {
                        id: sendLabel
                        anchors.centerIn: parent
                        text: "SEND"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shareInput.send()
                    }
                }
            }

            // Result of the last action
            Text {
                Layout.fillWidth: true
                visible: KdeConnectService.notice !== ""
                text: KdeConnectService.notice
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                color: KdeConnectService.noticeIsError ? Theme.accentRed : root.kcColor
                elide: Text.ElideRight
            }
        }
    }
}
