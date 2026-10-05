import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var notification: NotificationService.latestNotification

    implicitHeight: Theme.compactHeight
    implicitWidth: Theme.px(310)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.px(12)
        anchors.rightMargin: Theme.px(14)
        spacing: Theme.px(9)

        // Notification Icon Badge
        Rectangle {
            Layout.preferredWidth: Theme.px(26)
            Layout.preferredHeight: Theme.px(26)
            radius: Theme.px(13)
            color: Qt.rgba(255/255, 159/255, 10/255, 0.22)

            SvgIcon {
                anchors.centerIn: parent
                name: "bell"
                size: Theme.px(13)
                color: Theme.accentOrange
            }
        }

        // Notification Summary & Body
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(4)

                Text {
                    text: root.notification ? (root.notification.appName || "Notification") : "Notification"
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: Theme.accentOrange
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.notification && root.notification.summary && root.notification.summary.length > 0
                    text: "• " + (root.notification ? root.notification.summary : "")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                text: root.notification ? (root.notification.body || root.notification.summary || "") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
                maximumLineCount: 1
            }
        }

        // Right Pulse indicator dot
        Rectangle {
            Layout.preferredWidth: Theme.px(7)
            Layout.preferredHeight: Theme.px(7)
            radius: Theme.px(3.5)
            color: Theme.accentOrange

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
        }
    }
}
