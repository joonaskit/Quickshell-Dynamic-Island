import "../.."
import QtQuick
import QtQuick.Layouts

// Titled card that groups setting rows
ColumnLayout {
    id: section
    property string title: ""
    property string subtitle: ""
    property real titlePixelSize: 10
    default property alias rows: rowsCol.data

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 6

        Text {
            text: section.title
            font.family: Theme.fontFamily
            font.pixelSize: section.titlePixelSize
            font.weight: Font.DemiBold
            color: Theme.textTertiary
        }

        Text {
            visible: section.subtitle !== ""
            text: "• " + section.subtitle
            font.family: Theme.fontFamily
            font.pixelSize: section.titlePixelSize
            color: Qt.rgba(1, 1, 1, 0.25)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rowsCol.implicitHeight
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        ColumnLayout {
            id: rowsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0
        }
    }
}
