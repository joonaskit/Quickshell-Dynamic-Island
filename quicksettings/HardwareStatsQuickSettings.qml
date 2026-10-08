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
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? 10 : 14
            spacing: 12

            // Top Header: Badge & Status
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: Qt.rgba(10/255, 132/255, 255/255, 0.22)

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "cpu"
                        size: 20
                        color: Theme.accentBlue
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Hardware Monitor"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: "CPU " + HardwareStatsService.cpuPercent + "% • " + HardwareStatsService.cpuTemp + "°C"
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
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // 1. CPU Usage Meter
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "PROCESSOR (CPU)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: HardwareStatsService.cpuPercent + "%"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.accentBlue
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(8, parent.width * (HardwareStatsService.cpuPercent / 100.0))
                        radius: 4
                        color: Theme.accentBlue

                        Behavior on width { NumberAnimation { duration: Theme.animDurationProgress; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // 2. RAM Usage Meter
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "MEMORY (RAM)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: HardwareStatsService.ramUsedGb + " / " + HardwareStatsService.ramTotalGb + " GB (" + HardwareStatsService.ramPercent + "%)"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.accentPurple
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(8, parent.width * (HardwareStatsService.ramPercent / 100.0))
                        radius: 4
                        color: Theme.accentPurple

                        Behavior on width { NumberAnimation { duration: Theme.animDurationProgress; easing.type: Easing.OutQuad } }
                    }
                }
            }

            // 3. Thermal Status Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: HardwareStatsService.cpuTemp > 75 ? Theme.accentRed : (HardwareStatsService.cpuTemp > 60 ? Theme.accentOrange : Theme.accentGreen)
                    }

                    Text {
                        text: "CPU Temperature"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: HardwareStatsService.cpuTemp + " °C"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: HardwareStatsService.cpuTemp > 75 ? Theme.accentRed : (HardwareStatsService.cpuTemp > 60 ? Theme.accentOrange : Theme.accentGreen)
                    }
                }
            }
        }
    }
}
