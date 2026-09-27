import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: parent ? parent.width : 370
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        // Header: Bell Icon, Title, Count Badge & Clear All
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SvgIcon {
                name: "bell"
                size: 13
                color: Theme.accentOrange
            }

            Text {
                text: "NOTIFICATIONS"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }

            // Count Badge
            Rectangle {
                Layout.preferredHeight: 16
                Layout.preferredWidth: countText.implicitWidth + 8
                radius: 8
                color: Qt.rgba(255/255, 159/255, 10/255, 0.2)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: NotificationService.notifications.length
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.accentOrange
                }
            }

            Item { Layout.fillWidth: true }

            // Clear All Button
            Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: clearRow.implicitWidth + 12
                radius: 11
                color: clearMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                scale: clearMouse.pressed ? 0.92 : (clearMouse.containsMouse ? 1.08 : 1.0)

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                }

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    SvgIcon {
                        name: "trash"
                        size: 10
                        color: clearMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                    }

                    Text {
                        text: "Clear"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: clearMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NotificationService.clearAll();
                    }
                }
            }
        }

        // List of Notifications (up to 4 most recent)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: {
                    let list = NotificationService.notifications || [];
                    return list.slice(0, 4);
                }

                Rectangle {
                    id: notifCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: cardLayout.implicitHeight + 14
                    radius: 10
                    color: cardMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 7
                        spacing: 2

                        // Top line: App Name Badge, Time & Dismiss '✕' button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // App Name
                            Rectangle {
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: appText.implicitWidth + 8
                                radius: 4
                                color: Qt.rgba(10/255, 132/255, 255/255, 0.15)

                                Text {
                                    id: appText
                                    anchors.centerIn: parent
                                    text: modelData.appName || "System"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Theme.accentBlue
                                }
                            }

                            Text {
                                text: modelData.time || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textTertiary
                            }

                            Item { Layout.fillWidth: true }

                            // Dismiss button
                            Rectangle {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                radius: 9
                                color: dismissMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : "transparent"
                                scale: dismissMouse.pressed ? 0.88 : (dismissMouse.containsMouse ? 1.22 : 1.0)

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 9
                                    color: dismissMouse.containsMouse ? Theme.accentRed : Qt.rgba(1, 1, 1, 0.25)
                                }

                                MouseArea {
                                    id: dismissMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotificationService.dismissNotification(modelData.id);
                                    }
                                }
                            }
                        }

                        // Summary
                        Text {
                            visible: modelData.summary && modelData.summary.length > 0
                            Layout.fillWidth: true
                            text: modelData.summary || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        // Body
                        Text {
                            visible: modelData.body && modelData.body.length > 0
                            Layout.fillWidth: true
                            text: modelData.body || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                    }
                }
            }
        }

        // Empty state when no notifications
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            visible: NotificationService.notifications.length === 0

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                SvgIcon {
                    name: "bell"
                    size: 14
                    color: Qt.rgba(1, 1, 1, 0.25)
                }

                Text {
                    text: "No notifications"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.textTertiary
                }
            }
        }
    }
}
