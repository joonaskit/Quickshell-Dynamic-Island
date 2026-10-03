import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var appData: null
    property bool isOpen: false
    property real targetX: 0
    property real targetY: 0

    signal closed()

    visible: opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    scale: isOpen ? 1.0 : 0.92
    transformOrigin: Item.Bottom

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
    }

    readonly property bool isRunning: appData ? (DockService.runningStateMap[appData.id] ? DockService.runningStateMap[appData.id].running : false) : false
    readonly property bool isPinned: appData ? DockService.isPinned(appData.id) : false

    width: 180
    height: menuColumn.implicitHeight + 16

    x: Math.max(8, Math.min(parent.width - width - 8, targetX - width / 2))
    y: targetY - height - 10

    // Styled popup card
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 14
        color: "#1c1c1e"
        border.color: (WindowService.isMaximized || WindowService.hasFullscreenApp) ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
        border.width: (WindowService.isMaximized || WindowService.hasFullscreenApp) ? 0 : 1

        // Subtle top highlight border
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.20)
            visible: !(WindowService.isMaximized || WindowService.hasFullscreenApp)
        }
    }

    Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 3

        // App Name Header
        Item {
            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: appData ? appData.name : ""
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        // Separator
        Rectangle {
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // New Window button
        Rectangle {
            width: parent.width
            height: 28
            radius: 7
            color: newWinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                SvgIcon {
                    name: "window"
                    size: 14
                    color: Theme.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text: "New Window"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: newWinMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (appData) DockService.newWindow(appData);
                    root.isOpen = false;
                    root.closed();
                }
            }
        }

        // Pin / Unpin button
        Rectangle {
            width: parent.width
            height: 28
            radius: 7
            color: pinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                SvgIcon {
                    name: "check"
                    size: 14
                    color: root.isPinned ? Theme.accentBlue : Theme.textSecondary
                }

                Text {
                    Layout.fillWidth: true
                    text: root.isPinned ? "Remove from Dock" : "Keep in Dock"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: pinMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (appData) {
                        if (root.isPinned) {
                            DockService.unpinApp(appData.id);
                        } else {
                            DockService.pinApp(appData);
                        }
                    }
                    root.isOpen = false;
                    root.closed();
                }
            }
        }

        // Close / Quit button (visible if running)
        Rectangle {
            visible: root.isRunning
            width: parent.width
            height: 28
            radius: 7
            color: quitMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.25) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                SvgIcon {
                    name: "close"
                    size: 14
                    color: quitMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                }

                Text {
                    Layout.fillWidth: true
                    text: "Quit"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: quitMouse.containsMouse ? Theme.accentRed : Theme.textPrimary
                }
            }

            MouseArea {
                id: quitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (appData) DockService.quitApp(appData);
                    root.isOpen = false;
                    root.closed();
                }
            }
        }
    }
}
