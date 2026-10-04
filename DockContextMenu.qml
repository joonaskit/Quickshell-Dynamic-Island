import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var appData: null
    property bool isOpen: false
    property real targetX: 0
    property real targetY: 0
    property real dockCapsuleX: 0
    property real dockCapsuleY: 0
    property real dockCapsuleWidth: 0
    property bool isVertical: false
    property string dockPosition: "bottom"

    signal closed()

    visible: opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    scale: isOpen ? 1.0 : 0.92
    transformOrigin: isVertical ? (dockPosition === "left" ? Item.Left : Item.Right) : Item.Bottom

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
    }

    readonly property bool isRunning: appData ? (DockService.runningStateMap[appData.id] ? DockService.runningStateMap[appData.id].running : false) : false
    readonly property bool isPinned: appData ? DockService.isPinned(appData.id) : false
    readonly property var openWindows: appData ? DockService.findToplevels(appData) : []
    readonly property var desktopActions: appData ? DockService.getActionsForApp(appData) : []

    width: 220
    height: menuColumn.implicitHeight + 16

    x: {
        if (isVertical) {
            return dockPosition === "left" ? (dockCapsuleX + dockCapsuleWidth + 14) : (dockCapsuleX - width - 14);
        }
        return Math.max(8, Math.min(parent ? (parent.width - width - 8) : 500, targetX - width / 2));
    }
    y: {
        if (isVertical) {
            return Math.max(8, Math.min(parent ? (parent.height - height - 8) : 500, targetY - height / 2));
        }
        return (dockCapsuleY > 0 ? dockCapsuleY : (parent ? parent.height - Theme.dockHeight : targetY)) - height - 10;
    }

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

        // Open Windows Section (if running and has open windows)
        Repeater {
            model: root.openWindows

            delegate: Rectangle {
                id: winItem
                width: parent.width
                height: 28
                radius: 7
                color: winMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: modelData.activated ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.45)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (modelData.title && modelData.title.trim().length > 0) ? modelData.title : ("Window " + (index + 1))
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: modelData.activated ? Font.DemiBold : Font.Normal
                        color: modelData.activated ? Theme.accentBlue : Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    // Direct close window button
                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        radius: 9
                        color: closeWinMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.3) : "transparent"
                        opacity: winMouse.containsMouse ? 1.0 : 0.0

                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 10
                            color: closeWinMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                        }

                        MouseArea {
                            id: closeWinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.isKWin) {
                                    WindowService.closeWindow(modelData.id);
                                } else if (modelData.raw) {
                                    try { modelData.raw.close(); } catch(e) {}
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: winMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.isKWin) {
                            WindowService.activateWindow(modelData.id);
                        } else if (modelData.raw) {
                            if (modelData.raw.minimized) modelData.raw.minimized = false;
                            modelData.raw.activate();
                        }
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }
        }

        // Separator after open windows
        Rectangle {
            visible: root.openWindows.length > 0
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // Desktop Actions / Jumplists (e.g. New Private Window, New Tab, etc.)
        Repeater {
            model: root.desktopActions

            delegate: Rectangle {
                id: actionItem
                width: parent.width
                height: 28
                radius: 7
                color: actionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    SvgIcon {
                        name: "arrow-right"
                        size: 12
                        color: Theme.accentCyan
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name || "Action"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        try {
                            modelData.execute();
                        } catch(e) {
                            console.warn("[DockContextMenu] Error executing action:", e);
                        }
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }
        }

        // Separator after Desktop Actions
        Rectangle {
            visible: root.desktopActions.length > 0
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
