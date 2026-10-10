import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : 340) : 320
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
        color: root.embedded ? "transparent" : Theme.cardBackground
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? 10 : 14
            spacing: 12

            // Top Header: Performance Badge & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: {
                        if (PowerProfileService.activeProfile === "performance") return Qt.rgba(255/255, 69/255, 58/255, 0.22);
                        if (PowerProfileService.activeProfile === "power-saver") return Qt.rgba(48/255, 209/255, 88/255, 0.22);
                        return Qt.rgba(10/255, 132/255, 255/255, 0.22);
                    }

                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "gauge"
                        size: 20
                        color: {
                            if (PowerProfileService.activeProfile === "performance") return Theme.accentRed;
                            if (PowerProfileService.activeProfile === "power-saver") return Theme.accentGreen;
                            return Theme.accentBlue;
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Performance Mode"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (PowerProfileService.activeProfile === "performance") return "High Performance";
                            if (PowerProfileService.activeProfile === "power-saver") return "Power Saver";
                            return "Balanced";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Profile Selection Options
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // 1. Power Saver
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "power-saver"
                        ? Qt.rgba(48/255, 209/255, 88/255, 0.16)
                        : (saveMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: saveMouse.pressed ? 0.96 : (saveMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        SvgIcon {
                            name: "leaf"
                            size: 16
                            color: PowerProfileService.activeProfile === "power-saver" ? Theme.accentGreen : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Power Saver"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "power-saver" ? Theme.accentGreen : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Lower clock speeds, quiet fans"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: 14
                            color: Theme.accentGreen
                            opacity: PowerProfileService.activeProfile === "power-saver" ? 1.0 : 0.0
                            scale: PowerProfileService.activeProfile === "power-saver" ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                        }
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfileService.setProfile("power-saver")
                    }
                }

                // 2. Balanced
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "balanced"
                        ? Qt.rgba(10/255, 132/255, 255/255, 0.16)
                        : (balMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: balMouse.pressed ? 0.96 : (balMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        SvgIcon {
                            name: "gauge"
                            size: 16
                            color: PowerProfileService.activeProfile === "balanced" ? Theme.accentBlue : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Balanced"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "balanced" ? Theme.accentBlue : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Standard dynamic performance"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: 14
                            color: Theme.accentBlue
                            opacity: PowerProfileService.activeProfile === "balanced" ? 1.0 : 0.0
                            scale: PowerProfileService.activeProfile === "balanced" ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                        }
                    }

                    MouseArea {
                        id: balMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfileService.setProfile("balanced")
                    }
                }

                // 3. Performance
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "performance"
                        ? Qt.rgba(255/255, 69/255, 58/255, 0.16)
                        : (perfMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: perfMouse.pressed ? 0.96 : (perfMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        SvgIcon {
                            name: "bolt"
                            size: 16
                            color: PowerProfileService.activeProfile === "performance" ? Theme.accentRed : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Performance"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "performance" ? Theme.accentRed : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Maximum clock speed & throughput"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: 14
                            color: Theme.accentRed
                            opacity: PowerProfileService.activeProfile === "performance" ? 1.0 : 0.0
                            scale: PowerProfileService.activeProfile === "performance" ? 1.0 : 0.5
                            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                        }
                    }

                    MouseArea {
                        id: perfMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfileService.setProfile("performance")
                    }
                }
            }
        }
    }
}
