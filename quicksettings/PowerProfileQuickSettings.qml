import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

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
        color: root.embedded ? "transparent" : Theme.cardSurface
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

            // Top Header: Performance Badge & Title
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: {
                        if (PowerProfileService.activeProfile === "performance") return Qt.rgba(255/255, 69/255, 58/255, 0.22);
                        if (PowerProfileService.activeProfile === "power-saver") return Qt.rgba(48/255, 209/255, 88/255, 0.22);
                        return Qt.rgba(10/255, 132/255, 255/255, 0.22);
                    }

                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "gauge"
                        size: Theme.px(20)
                        color: {
                            if (PowerProfileService.activeProfile === "performance") return Theme.accentRed;
                            if (PowerProfileService.activeProfile === "power-saver") return Theme.accentGreenStrong;
                            return Theme.accentBlue;
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Performance Mode"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
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
                        font.pixelSize: Theme.fontPx(11)
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
                spacing: Theme.px(6)

                // 1. Power Saver
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(46)
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "power-saver"
                        ? Qt.rgba(48/255, 209/255, 88/255, 0.16)
                        : (saveMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: saveMouse.pressed ? 0.96 : (saveMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        SvgIcon {
                            name: "leaf"
                            size: Theme.px(16)
                            color: PowerProfileService.activeProfile === "power-saver" ? Theme.accentGreenStrong : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Power Saver"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "power-saver" ? Theme.accentGreenStrong : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Lower clock speeds, quiet fans"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: Theme.px(14)
                            color: Theme.accentGreenStrong
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
                    Layout.preferredHeight: Theme.px(46)
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "balanced"
                        ? Qt.rgba(10/255, 132/255, 255/255, 0.16)
                        : (balMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: balMouse.pressed ? 0.96 : (balMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        SvgIcon {
                            name: "gauge"
                            size: Theme.px(16)
                            color: PowerProfileService.activeProfile === "balanced" ? Theme.accentBlue : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Balanced"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "balanced" ? Theme.accentBlue : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Standard dynamic performance"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: Theme.px(14)
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
                    Layout.preferredHeight: Theme.px(46)
                    radius: Theme.corner(10)
                    color: PowerProfileService.activeProfile === "performance"
                        ? Qt.rgba(255/255, 69/255, 58/255, 0.16)
                        : (perfMouse.containsMouse ? Theme.overlay(0.06) : Theme.overlay(0.03))
                    scale: perfMouse.pressed ? 0.96 : (perfMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(10)
                        spacing: Theme.px(10)

                        SvgIcon {
                            name: "bolt"
                            size: Theme.px(16)
                            color: PowerProfileService.activeProfile === "performance" ? Theme.accentRed : Theme.textTertiary
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Performance"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.DemiBold
                                color: PowerProfileService.activeProfile === "performance" ? Theme.accentRed : Theme.textPrimary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }
                            Text {
                                text: "Maximum clock speed & throughput"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.textTertiary
                            }
                        }

                        SvgIcon {
                            name: "check"
                            size: Theme.px(14)
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

            // 60 Hz on battery, shown on machines with a battery
            Rectangle {
                visible: lowRefreshRow.visible
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            RowLayout {
                id: lowRefreshRow
                visible: UPower.displayDevice !== null && UPower.displayDevice.isPresent
                Layout.fillWidth: true
                spacing: Theme.px(10)

                SvgIcon {
                    name: "desktop"
                    size: Theme.px(16)
                    color: SettingsService.lowRefreshOnBattery ? Theme.accentGreenStrong : Theme.textTertiary
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "60 Hz on battery"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Lowers the built-in screen's refresh rate while unplugged"
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        color: Theme.textTertiary
                    }
                }

                // Toggle switch
                Rectangle {
                    Layout.preferredWidth: Theme.px(46)
                    Layout.preferredHeight: Theme.px(26)
                    radius: Theme.px(13)
                    color: SettingsService.lowRefreshOnBattery ? Theme.accentGreen : Theme.controlTrackOff

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    // Sliding Knob
                    Rectangle {
                        y: Theme.px(2)
                        x: SettingsService.lowRefreshOnBattery ? Theme.px(22) : Theme.px(2)
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
                        onClicked: SettingsService.toggleSetting("lowRefreshOnBattery")
                    }
                }
            }
        }
    }
}
