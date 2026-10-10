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

            // Top Header: Badge & Status
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: Qt.rgba(10/255, 132/255, 255/255, 0.22)

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "cpu"
                        size: Theme.px(20)
                        color: Theme.accentBlue
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Hardware Monitor"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "CPU " + HardwareStatsService.cpuPercent + "% • " + HardwareStatsService.cpuTemp + "°C"
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

            // 1. CPU Usage Meter
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(4)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "PROCESSOR (CPU)"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: HardwareStatsService.cpuPercent + "%"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.DemiBold
                        color: Theme.accentBlue
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(8)
                    radius: Theme.px(4)
                    color: Theme.overlay(0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(8, parent.width * (HardwareStatsService.cpuPercent / 100.0))
                        radius: Theme.corner(4)
                        color: Theme.accentBlue

                        Behavior on width { NumberAnimation { duration: Theme.animDurationProgress; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // 2. RAM Usage Meter
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(4)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "MEMORY (RAM)"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: HardwareStatsService.ramUsedGb + " / " + HardwareStatsService.ramTotalGb + " GB (" + HardwareStatsService.ramPercent + "%)"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.DemiBold
                        color: Theme.accentPurple
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(8)
                    radius: Theme.px(4)
                    color: Theme.overlay(0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(8, parent.width * (HardwareStatsService.ramPercent / 100.0))
                        radius: Theme.corner(4)
                        color: Theme.accentPurple

                        Behavior on width { NumberAnimation { duration: Theme.animDurationProgress; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // 3. Thermal Status Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(38)
                radius: Theme.corner(8)
                color: Theme.overlay(0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(10)
                    anchors.rightMargin: Theme.px(10)
                    spacing: Theme.px(8)

                    Rectangle {
                        Layout.preferredWidth: Theme.px(8)
                        Layout.preferredHeight: Theme.px(8)
                        radius: Theme.px(4)
                        color: HardwareStatsService.cpuTemp > 75 ? Theme.accentRed : (HardwareStatsService.cpuTemp > 60 ? Theme.accentOrange : Theme.accentGreen)
                    }

                    Text {
                        text: "CPU Temperature"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: HardwareStatsService.cpuTemp + " °C"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Bold
                        color: HardwareStatsService.cpuTemp > 75 ? Theme.accentRed : (HardwareStatsService.cpuTemp > 60 ? Theme.accentOrange : Theme.accentGreen)
                    }
                }
            }
        }
    }
}
