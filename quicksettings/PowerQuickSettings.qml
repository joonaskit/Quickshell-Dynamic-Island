import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Item {
    id: root

    signal requestClose()

    property var battery: UPower.displayDevice
    property bool isPresent: battery !== null && battery.isPresent
    property real percentage: isPresent ? Math.min(1.0, Math.max(0.0, battery.percentage <= 1.0 ? battery.percentage : battery.percentage / 100.0)) : 1.0
    property bool isCharging: isPresent && battery.state === UPowerDeviceState.Charging
    property bool isFull: isPresent && (battery.state === UPowerDeviceState.FullyCharged || percentage >= 0.99)

    function formatTimeRemaining(seconds) {
        if (!seconds || isNaN(seconds) || seconds <= 0) return "";
        let hrs = Math.floor(seconds / 3600);
        let mins = Math.floor((seconds % 3600) / 60);
        if (hrs > 0) return hrs + "h " + mins + "m";
        return mins + "m";
    }

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
            spacing: 14

            // Top Header: Battery Status Overview
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Battery / Power Icon Badge
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: !root.isPresent
                        ? Qt.rgba(255/255, 214/255, 10/255, 0.2)
                        : (root.isCharging ? Qt.rgba(48/255, 209/255, 88/255, 0.2) : Qt.rgba(1, 1, 1, 0.08))

                    SvgIcon {
                        anchors.centerIn: parent
                        name: !root.isPresent ? "nuclear" : (root.isCharging ? "bolt" : "battery")
                        size: 20
                        color: !root.isPresent ? Theme.accentYellow : (root.isCharging ? Theme.accentGreen : Theme.textPrimary)
                    }
                }

                // Battery Status Readout
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 6

                        Text {
                            text: !root.isPresent ? "Direct Power" : "Battery"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: Math.round(root.percentage * 100) + "%"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: root.isCharging ? Theme.accentGreen : Theme.textPrimary
                            visible: root.isPresent
                        }
                    }

                    Text {
                        text: {
                            if (!root.isPresent) return "Desktop workstation (direct line power)";
                            if (root.isFull) return "Fully Charged";
                            if (root.isCharging) {
                                let rem = root.formatTimeRemaining(root.battery.timeToFull);
                                return rem !== "" ? "Charging (" + rem + " until full)" : "Charging on AC Power";
                            }
                            let rem = root.formatTimeRemaining(root.battery.timeToEmpty);
                            return rem !== "" ? rem + " remaining" : "On Battery Power";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // System Power Actions Title
            Text {
                text: "POWER OPTIONS"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }

            // 4 Grid Action Tiles: Lock, Sleep, Restart, Shut Down
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // 1. Lock Screen
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: lockMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(10/255, 132/255, 255/255, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "lock"
                                size: 14
                                color: Theme.accentBlue
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Lock"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: lockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PowerService.lock();
                            root.requestClose();
                        }
                    }
                }

                // 2. Sleep / Suspend
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: sleepMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(94/255, 92/255, 230/255, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "moon"
                                size: 14
                                color: "#5e5ce6"
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Sleep"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: sleepMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PowerService.sleep();
                            root.requestClose();
                        }
                    }
                }

                // 3. Restart
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: restartMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(255/255, 159/255, 10/255, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "restart"
                                size: 14
                                color: Theme.accentOrange
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Restart"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PowerService.restart();
                            root.requestClose();
                        }
                    }
                }

                // 4. Shut Down
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 12
                    color: shutdownMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(255/255, 69/255, 58/255, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "power"
                                size: 14
                                color: Theme.accentRed
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Shut Down"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: shutdownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PowerService.shutdown();
                            root.requestClose();
                        }
                    }
                }
            }

            // Divider before Settings
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Footer Link: Energy & Power Settings...
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
                        text: "Energy & Battery Settings..."
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
                        PowerService.openSettings();
                        root.requestClose();
                    }
                }
            }
        }
    }
}
