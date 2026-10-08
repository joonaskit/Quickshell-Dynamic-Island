import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property date currentTime: new Date()
    property bool use24Hour: Theme.use24Hour
    property bool isHovered: false

    implicitHeight: Theme.compactHeight
    implicitWidth: contentRow.implicitWidth + Theme.px(24)

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.px(8)

        // Sleek subtle clock icon or glowing accent dot
        Item {
            Layout.preferredWidth: Theme.px(18)
            Layout.preferredHeight: Theme.px(18)
            Layout.alignment: Qt.AlignVCenter

            // Soft glowing pulse behind icon
            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(14)
                height: Theme.px(14)
                radius: Theme.px(7)
                color: Theme.accent
                opacity: root.isHovered ? 0.35 : 0.15

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            SvgIcon {
                anchors.centerIn: parent
                name: "clock"
                size: Theme.px(14)
                color: root.isHovered ? Theme.accent : Theme.overlay(0.75)

                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }
        }

        // Time display
        Text {
            id: timeText
            text: {
                if (root.use24Hour) {
                    return Qt.formatDateTime(root.currentTime, "hh:mm");
                } else {
                    return Qt.formatDateTime(root.currentTime, "h:mm AP");
                }
            }
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(15)
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            font.features: { "tnum": 1 }
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        // Weekday / short date badge
        Text {
            id: dateBadge
            text: Qt.formatDateTime(root.currentTime, "ddd").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(10)
            font.weight: Font.Bold
            color: Theme.textSecondary
            opacity: 0.8
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: Theme.px(2)
        }
    }
}
