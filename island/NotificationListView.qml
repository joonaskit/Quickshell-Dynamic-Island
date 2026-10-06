import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(8)

        // Header: Bell Icon, Title, Count Badge & Clear All
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            SvgIcon {
                name: "bell"
                size: Theme.px(13)
                color: Theme.accentOrange
            }

            Text {
                text: "NOTIFICATIONS"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }

            // Count Badge
            Rectangle {
                Layout.preferredHeight: Theme.px(16)
                Layout.preferredWidth: countText.implicitWidth + Theme.px(8)
                radius: Theme.px(8)
                color: Qt.rgba(255/255, 159/255, 10/255, 0.2)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: NotificationService.notifications.length
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.Bold
                    color: Theme.accentOrange
                }
            }

            Item { Layout.fillWidth: true }

            // Do Not Disturb Toggle
            Rectangle {
                Layout.preferredHeight: Theme.px(22)
                Layout.preferredWidth: dndRow.implicitWidth + Theme.px(12)
                radius: Theme.px(11)
                color: SettingsService.dndEnabled ? Qt.rgba(191/255, 90/255, 242/255, 0.22) : (dndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                scale: dndMouse.pressed ? 0.92 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: Theme.px(4)

                    SvgIcon {
                        name: "bell-off"
                        size: Theme.px(10)
                        color: SettingsService.dndEnabled ? Theme.accentPurple : Theme.textSecondary
                    }

                    Text {
                        text: "DND"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: SettingsService.dndEnabled ? Theme.accentPurple : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.toggleDnd()
                }
            }

            // Clear All Button
            Rectangle {
                Layout.preferredHeight: Theme.px(22)
                Layout.preferredWidth: clearRow.implicitWidth + Theme.px(12)
                radius: Theme.px(11)
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
                    spacing: Theme.px(4)

                    SvgIcon {
                        name: "trash"
                        size: Theme.px(10)
                        color: clearMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                    }

                    Text {
                        text: "Clear"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
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
            spacing: Theme.px(6)

            Repeater {
                model: {
                    let list = NotificationService.notifications || [];
                    return list.slice(0, 4);
                }

                Rectangle {
                    id: notifCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: cardLayout.implicitHeight + Theme.px(14)
                    radius: Theme.px(10)
                    color: cardMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    // Spring-in on creation
                    scale: 1.0
                    opacity: 1.0
                    Component.onCompleted: {
                        scale = 0.92;
                        opacity = 0.0;
                        scaleAnim.start();
                        opacityAnim.start();
                    }
                    NumberAnimation { id: scaleAnim; target: notifCard; property: "scale"; to: 1.0; duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
                    NumberAnimation { id: opacityAnim; target: notifCard; property: "opacity"; to: 1.0; duration: Theme.animDurationFast }

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.px(7)
                        spacing: Theme.px(2)

                        // Top line: App Name Badge, Time & Dismiss '✕' button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.px(6)

                            // App Name
                            Rectangle {
                                Layout.preferredHeight: Theme.px(16)
                                Layout.preferredWidth: appText.implicitWidth + Theme.px(8)
                                radius: Theme.px(4)
                                color: Qt.rgba(10/255, 132/255, 255/255, 0.15)

                                Text {
                                    id: appText
                                    anchors.centerIn: parent
                                    text: modelData.appName || "System"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.DemiBold
                                    color: Theme.accentBlue
                                }
                            }

                            Text {
                                text: modelData.time || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.textTertiary
                            }

                            Item { Layout.fillWidth: true }

                            // Dismiss button
                            Rectangle {
                                Layout.preferredWidth: Theme.px(18)
                                Layout.preferredHeight: Theme.px(18)
                                radius: Theme.px(9)
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
                                    size: Theme.px(9)
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
                            font.pixelSize: Theme.fontPx(11)
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
                            font.pixelSize: Theme.fontPx(10)
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
            Layout.preferredHeight: Theme.px(58)
            radius: Theme.px(10)
            color: Qt.rgba(1, 1, 1, 0.03)
            opacity: NotificationService.notifications.length === 0 ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.px(8)

                SvgIcon {
                    name: "bell"
                    size: Theme.px(14)
                    color: Qt.rgba(1, 1, 1, 0.25)
                }

                Text {
                    text: "No notifications"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: Theme.textTertiary
                }
            }
        }
    }
}
