import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property date currentTime: new Date()
    property bool use24Hour: Theme.use24Hour
    property bool isHovered: false

    implicitHeight: Theme.compactHeight
    implicitWidth: contentRow.implicitWidth + 24

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        // Sleek subtle clock icon or glowing accent dot
        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            // Soft glowing pulse behind icon
            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: Theme.accentBlue
                opacity: root.isHovered ? 0.35 : 0.15

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            SvgIcon {
                anchors.centerIn: parent
                name: "clock"
                size: 14
                color: root.isHovered ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.75)

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
            font.pixelSize: 15
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
            font.pixelSize: 10
            font.weight: Font.Bold
            color: Theme.textSecondary
            opacity: 0.8
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 2
        }
    }
}
