import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool confirmingClear: false
    // appName -> true for groups the user expanded
    property var expandedGroups: ({})

    function toggleGroup(appName) {
        let next = Object.assign({}, root.expandedGroups);
        next[appName] = !next[appName];
        root.expandedGroups = next;
    }

    // Reset the confirm prompt if the user doesn't follow up
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmingClear = false
    }

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
                color: SettingsService.dndEnabled ? Qt.rgba(191/255, 90/255, 242/255, 0.22) : (dndMouse.containsMouse ? Theme.overlay(0.1) : Theme.overlay(0.05))
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

            // Clear All Button (asks to confirm with a second click)
            Rectangle {
                Layout.preferredHeight: Theme.px(22)
                Layout.preferredWidth: clearRow.implicitWidth + Theme.px(12)
                radius: Theme.px(11)
                color: root.confirmingClear ? Qt.rgba(255/255, 69/255, 58/255, 0.32)
                     : (clearMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.2) : Theme.overlay(0.05))
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
                        color: (root.confirmingClear || clearMouse.containsMouse) ? Theme.accentRed : Theme.textSecondary
                    }

                    Text {
                        text: root.confirmingClear ? "Clear all?" : "Clear"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: (root.confirmingClear || clearMouse.containsMouse) ? Theme.accentRed : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.confirmingClear) {
                            root.confirmingClear = false;
                            confirmTimer.stop();
                            NotificationService.clearAll();
                        } else {
                            root.confirmingClear = true;
                            confirmTimer.restart();
                        }
                    }
                }
            }
        }

        // Notifications grouped by app (newest group first)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(8)

            Repeater {
                // Show at most the 4 most recently active apps
                model: (NotificationService.groups || []).slice(0, 4)

                delegate: ColumnLayout {
                    id: groupBlock
                    required property var modelData

                    readonly property bool multi: modelData.items.length > 1
                    readonly property bool groupExpanded: !!root.expandedGroups[modelData.appName]

                    Layout.fillWidth: true
                    spacing: Theme.px(4)

                    // Group header for apps with several notifications
                    RowLayout {
                        visible: groupBlock.multi
                        Layout.fillWidth: true
                        spacing: Theme.px(6)

                        Rectangle {
                            Layout.preferredHeight: Theme.px(16)
                            Layout.preferredWidth: groupAppText.implicitWidth + Theme.px(8)
                            radius: Theme.px(4)
                            color: Theme.accentTint(0.15)

                            Text {
                                id: groupAppText
                                anchors.centerIn: parent
                                text: groupBlock.modelData.appName
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(9)
                                font.weight: Font.DemiBold
                                color: Theme.accent
                            }
                        }

                        // Expand / collapse chip
                        Rectangle {
                            Layout.preferredHeight: Theme.px(16)
                            Layout.preferredWidth: chipRow.implicitWidth + Theme.px(10)
                            radius: Theme.px(8)
                            color: chipMouse.containsMouse ? Theme.overlay(0.12) : Theme.overlay(0.06)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Theme.px(3)

                                Text {
                                    text: groupBlock.groupExpanded ? "Show less" : ("+" + (groupBlock.modelData.items.length - 1) + " more")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.DemiBold
                                    color: Theme.textSecondary
                                }

                                SvgIcon {
                                    name: groupBlock.groupExpanded ? "chevron-up" : "chevron-down"
                                    size: Theme.px(9)
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleGroup(groupBlock.modelData.appName)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Clear this app's notifications
                        Rectangle {
                            Layout.preferredWidth: Theme.px(18)
                            Layout.preferredHeight: Theme.px(18)
                            radius: Theme.px(9)
                            color: groupClearMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "trash"
                                size: Theme.px(10)
                                color: groupClearMouse.containsMouse ? Theme.accentRed : Theme.overlay(0.3)
                            }

                            MouseArea {
                                id: groupClearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationService.dismissGroup(groupBlock.modelData.appName)
                            }
                        }
                    }

                    // Cards: newest only when collapsed, all (up to 6) when expanded
                    Repeater {
                        model: groupBlock.groupExpanded ? groupBlock.modelData.items.slice(0, 6) : groupBlock.modelData.items.slice(0, 1)

                        delegate: NotificationCard {
                            required property var modelData
                            notif: modelData
                            showApp: !groupBlock.multi
                        }
                    }
                }
            }
        }

        // Empty state when no notifications
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(58)
            radius: Theme.px(10)
            color: Theme.overlay(0.03)
            opacity: NotificationService.notifications.length === 0 ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.px(8)

                SvgIcon {
                    name: "bell"
                    size: Theme.px(14)
                    color: Theme.overlay(0.25)
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
