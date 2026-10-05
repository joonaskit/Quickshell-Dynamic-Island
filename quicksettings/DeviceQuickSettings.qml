import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : Theme.px(340)) : Theme.px(320)
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
        height: contentColumn.implicitHeight + (root.embedded ? 14 : Theme.px(28))
        radius: root.embedded ? 0 : Theme.px(18)
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

            // Top Header: USB Badge, Title, Status & Refresh Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Circular Device Badge
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: {
                        if (DeviceService.hasMountedDevices) return Qt.rgba(48/255, 209/255, 88/255, 0.22);
                        if (DeviceService.hasDevices) return Qt.rgba(10/255, 132/255, 255/255, 0.22);
                        return "#2c2c2e";
                    }

                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "usb"
                        size: 20
                        color: {
                            if (DeviceService.hasMountedDevices) return Theme.accentGreen;
                            if (DeviceService.hasDevices) return Theme.accentBlue;
                            return Theme.textTertiary;
                        }
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            DeviceService.scanDevices();
                        }
                    }
                }

                // Title & Subtitle Readout
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Detachable Devices"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (DeviceService.operatingDevice !== "") {
                                return DeviceService.statusMessage !== "" ? DeviceService.statusMessage : "Operating...";
                            }
                            if (DeviceService.hasDevices) {
                                let s = DeviceService.deviceCount + (DeviceService.deviceCount === 1 ? " drive" : " drives");
                                if (DeviceService.mountedCount > 0) {
                                    s += " • " + DeviceService.mountedCount + " mounted";
                                } else {
                                    s += " • unmounted";
                                }
                                return s;
                            }
                            return "No detachable drives detected";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: {
                            if (DeviceService.operatingDevice !== "") return Theme.accentOrange;
                            if (DeviceService.hasMountedDevices) return Theme.accentGreen;
                            if (DeviceService.hasDevices) return Theme.textSecondary;
                            return Theme.textTertiary;
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Refresh / Rescan Button
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: refreshMouse.containsMouse ? Theme.cardBackgroundHover : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 13
                        color: refreshMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            DeviceService.scanDevices();
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

            // Empty State
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                visible: !DeviceService.hasDevices

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: Qt.rgba(1, 1, 1, 0.05)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "usb"
                            size: 22
                            color: Theme.textTertiary
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No Detachable Drives"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Connect a USB drive or external disk"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textTertiary
                    }
                }
            }

            // Devices List
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: DeviceService.hasDevices

                Repeater {
                    model: DeviceService.devices

                    delegate: Rectangle {
                        id: deviceCard
                        Layout.fillWidth: true
                        implicitHeight: devCardCol.implicitHeight + 16
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        ColumnLayout {
                            id: devCardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8

                            // Device Card Header: Icon, Name, Size & Safe Eject
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: modelData.isMounted ? Qt.rgba(48/255, 209/255, 88/255, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: modelData.isMounted ? "usb" : "harddrive"
                                        size: 15
                                        color: modelData.isMounted ? Theme.accentGreen : Theme.textSecondary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.title || modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: (modelData.sizeFormatted ? modelData.sizeFormatted : "") + " • " + modelData.path
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: Theme.textTertiary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Safe Eject / Power Off Button
                                Rectangle {
                                    id: ejectBtn
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: ejectRow.implicitWidth + 14
                                    radius: 12
                                    property bool isBusy: DeviceService.operatingDevice === modelData.path
                                    enabled: !isBusy
                                    opacity: isBusy ? 0.5 : 1.0
                                    color: ejectMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                                    RowLayout {
                                        id: ejectRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        SvgIcon {
                                            name: "eject"
                                            size: 11
                                            color: ejectMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                                        }

                                        Text {
                                            text: "Eject"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: ejectMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                                        }
                                    }

                                    MouseArea {
                                        id: ejectMouse
                                        anchors.fill: parent
                                        hoverEnabled: parent.enabled
                                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            DeviceService.powerOffDevice(modelData.path);
                                        }
                                    }
                                }
                            }

                            // Partitions List
                            Repeater {
                                model: modelData.partitions

                                delegate: Rectangle {
                                    id: partItem
                                    Layout.fillWidth: true
                                    implicitHeight: partCol.implicitHeight + 12
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.04)

                                    ColumnLayout {
                                        id: partCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        spacing: 6

                                        // Partition Title & Status Badge
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Rectangle {
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: modelData.isMounted ? Theme.accentGreen : Theme.textTertiary
                                            }

                                            Text {
                                                text: modelData.title
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: {
                                                    if (modelData.isMounted && modelData.availFormatted !== "") {
                                                        return modelData.availFormatted + " free";
                                                    }
                                                    return modelData.sizeFormatted;
                                                }
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.textSecondary
                                            }
                                        }

                                        // Storage Usage Meter (if mounted)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            visible: modelData.isMounted

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 4
                                                radius: 2
                                                color: Qt.rgba(1, 1, 1, 0.12)
                                                clip: true

                                                Rectangle {
                                                    height: parent.height
                                                    radius: parent.radius
                                                    width: Math.max(4, parent.width * (Math.min(100, Math.max(0, modelData.usePercent)) / 100.0))
                                                    color: {
                                                        if (modelData.usePercent > 90) return Theme.accentRed;
                                                        if (modelData.usePercent > 75) return Theme.accentOrange;
                                                        return Theme.accentBlue;
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: modelData.mountpoint
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    color: Theme.textTertiary
                                                    elide: Text.ElideMiddle
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: modelData.usePercent + "% used"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 9
                                                    color: Theme.textTertiary
                                                }
                                            }
                                        }

                                        // Partition Action Controls
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Item { Layout.fillWidth: true }

                                            // Browse / Open in File Manager (if mounted)
                                            Rectangle {
                                                visible: modelData.isMounted
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: browseRow.implicitWidth + 14
                                                radius: 12
                                                color: browseMouse.containsMouse ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : Qt.rgba(1, 1, 1, 0.08)

                                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                                                RowLayout {
                                                    id: browseRow
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    SvgIcon {
                                                        name: "folder"
                                                        size: 11
                                                        color: browseMouse.containsMouse ? Theme.accentBlue : Theme.textSecondary
                                                    }

                                                    Text {
                                                        text: "Open"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        color: browseMouse.containsMouse ? Theme.accentBlue : Theme.textSecondary
                                                    }
                                                }

                                                MouseArea {
                                                    id: browseMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        DeviceService.openDevice(modelData.mountpoint);
                                                    }
                                                }
                                            }

                                            // Mount / Unmount Toggle Button
                                            Rectangle {
                                                id: mountToggleBtn
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: mountToggleRow.implicitWidth + 16
                                                radius: 12
                                                property bool isBusy: DeviceService.operatingDevice === modelData.path
                                                enabled: !isBusy
                                                opacity: isBusy ? 0.5 : 1.0

                                                color: {
                                                    if (modelData.isMounted) {
                                                        return mountToggleMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : Qt.rgba(255/255, 69/255, 58/255, 0.12);
                                                    } else {
                                                        return mountToggleMouse.containsMouse ? Qt.rgba(10/255, 132/255, 255/255, 0.35) : Qt.rgba(10/255, 132/255, 255/255, 0.2);
                                                    }
                                                }

                                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                                                RowLayout {
                                                    id: mountToggleRow
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    SvgIcon {
                                                        name: modelData.isMounted ? "eject" : "check"
                                                        size: 11
                                                        color: modelData.isMounted ? Theme.accentRed : Theme.accentBlue
                                                    }

                                                    Text {
                                                        text: {
                                                            if (mountToggleBtn.isBusy) {
                                                                return modelData.isMounted ? "Unmounting..." : "Mounting...";
                                                            }
                                                            return modelData.isMounted ? "Unmount" : "Mount";
                                                        }
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 10
                                                        font.weight: Font.DemiBold
                                                        color: modelData.isMounted ? Theme.accentRed : Theme.accentBlue
                                                    }
                                                }

                                                MouseArea {
                                                    id: mountToggleMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: parent.enabled
                                                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: {
                                                        if (modelData.isMounted) {
                                                            DeviceService.unmountDevice(modelData.path);
                                                        } else {
                                                            DeviceService.mountDevice(modelData.path);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
