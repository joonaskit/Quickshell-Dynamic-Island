import ".."
import QtQuick
import QtQuick.Layouts

// The alerting notification opened in place: full card with actions and
// reply, plus a link to the notification history in the status cluster.
Item {
    id: root

    property var notification: null
    readonly property bool replyActive: card.replyActive

    signal requestShowAll()

    implicitHeight: content.implicitHeight + Theme.px(28)

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.px(14)
        spacing: Theme.px(8)

        NotificationCard {
            id: card
            notif: root.notification
            bodyMaxLines: 8
        }

        // "Show all" link
        Item {
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: showAllRow.implicitWidth
            Layout.preferredHeight: showAllRow.implicitHeight

            RowLayout {
                id: showAllRow
                anchors.fill: parent
                spacing: Theme.px(2)

                Text {
                    text: NotificationService.notifications.length > 1
                        ? "Show all (" + NotificationService.notifications.length + ")"
                        : "Show all"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.DemiBold
                    color: showAllMouse.containsMouse ? Theme.accent : Theme.textSecondary

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                SvgIcon {
                    name: "chevron-right"
                    size: Theme.px(11)
                    color: showAllMouse.containsMouse ? Theme.accent : Theme.textSecondary
                }
            }

            MouseArea {
                id: showAllMouse
                anchors.fill: parent
                anchors.margins: -Theme.px(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestShowAll()
            }
        }
    }
}
