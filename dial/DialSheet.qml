import ".."
import QtQuick

// A sheet of the dial: the small form a status page opens for what the rings cannot hold,
// such as a bridge address or a pair of times. It sits over the disc below the pill.
// The header is the page's readout again (an icon in a disc of the sheet's colour, a
// title and a status line); under it come the sheet's own rows (DialField, plain Text
// notes) and a row of DialButtons.
//
// The window that shows a sheet listens to `closeRequested` (go back to where the sheet
// was opened from) and `pageRequested` (go to that page of the dial), and calls
// takeFocus() once it is shown.
Item {
    id: root

    property string icon: ""
    property color tint: Theme.accentBlue
    property string title: ""
    property string status: ""
    // Colour of the status line, for a warning or an error
    property color statusColor: Theme.textSecondary
    // The item that takes the keys when the sheet opens (a DialField), or null
    property DialField focusItem: null

    default property alias content: body.data
    // The buttons along the bottom
    property alias buttons: buttonRow.data

    signal closeRequested()
    signal pageRequested(string page)

    function takeFocus() {
        if (focusItem) focusItem.takeFocus();
    }

    implicitWidth: Theme.px(320)
    implicitHeight: column.implicitHeight + Theme.px(36)

    Column {
        id: column
        x: Theme.px(22)
        y: Theme.px(20)
        width: parent.width - Theme.px(44)
        spacing: Theme.px(14)

        Column {
            width: parent.width
            spacing: Theme.px(4)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.px(40)
                height: width
                radius: width / 2
                color: Qt.alpha(root.tint, 0.2)

                SvgIcon {
                    anchors.centerIn: parent
                    name: root.icon
                    size: Theme.px(18)
                    color: root.tint
                }
            }
            Item { width: 1; height: Theme.px(2) }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontPx(18)
                font.bold: true
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: root.status
                color: root.statusColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.px(8)
        }

        Row {
            id: buttonRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.px(8)
        }
    }
}
