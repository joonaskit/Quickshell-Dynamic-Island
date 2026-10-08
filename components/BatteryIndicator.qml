import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Item {
    id: root

    property var battery: UPower.displayDevice
    property bool isPresent: battery !== null && battery.isPresent
    property real percentage: isPresent ? Math.min(1.0, Math.max(0.0, battery.percentage <= 1.0 ? battery.percentage : battery.percentage / 100.0)) : 1.0
    property bool isCharging: isPresent && battery.state === UPowerDeviceState.Charging
    property bool isLow: percentage <= 0.20 && !isCharging
    property bool showPercentage: true

    implicitWidth: contentRow.implicitWidth
    implicitHeight: Theme.px(18)

    RowLayout {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(5)

        // Battery percentage text
        Text {
            visible: root.showPercentage && root.isPresent
            text: Math.round(root.percentage * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        // Nuclear icon when running on direct line power (no battery detected)
        SvgIcon {
            name: "nuclear"
            size: Theme.px(15)
            color: Theme.accentYellow
            visible: !root.isPresent
            Layout.alignment: Qt.AlignVCenter
        }

        // battery capsule (when battery is present)
        Row {
            visible: root.isPresent
            Layout.alignment: Qt.AlignVCenter
            spacing: Math.max(1, Theme.px(1.5))

            // Main Pill Capsule
            Rectangle {
                id: capsule
                width: Theme.px(25)
                height: Theme.px(12.5)
                radius: Theme.px(3.5)
                color: "transparent"
                border.width: 1.2
                border.color: Theme.overlay(0.55)

                // Battery Fill level
                Rectangle {
                    id: fillLevel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1.8
                    radius: 2
                    width: Math.max(2, (parent.width - 3.6) * root.percentage)

                    color: {
                        if (root.isCharging) return Theme.accentGreen;
                        if (root.isLow) return Theme.accentRed;
                        return Theme.textPrimary;
                    }

                    Behavior on width {
                        NumberAnimation { duration: 300 }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                // Tiny lightning bolt inside if charging
                SvgIcon {
                    anchors.centerIn: parent
                    name: "bolt"
                    size: Theme.px(9)
                    color: root.percentage > 0.55 ? Theme.lightForeground : Theme.accentGreen
                    visible: root.isCharging
                }
            }

            // Positive terminal cap
            Rectangle {
                width: Math.max(1, Theme.px(1.5))
                height: Theme.px(4.5)
                radius: 0.8
                anchors.verticalCenter: capsule.verticalCenter
                color: Theme.overlay(0.55)
            }
        }
    }
}
