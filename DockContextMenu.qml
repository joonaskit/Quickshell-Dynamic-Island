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
    readonly property var mprisPlayer: appData ? DockService.getMprisPlayerForApp(appData) : null

    width: 230
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
        border.color: Theme.dockBorder
        border.width: Theme.dockShowBorder ? 1 : 0
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
                text: root.appData ? root.appData.name : ""
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }

        // MPRIS Media Controls Section (active when app has a media player)
        Item {
            visible: root.mprisPlayer !== null
            width: parent.width
            height: visible ? 52 : 0

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.08)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "music"
                            size: 13
                            color: Theme.accentOrange
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: (root.mprisPlayer && root.mprisPlayer.trackTitle) ? root.mprisPlayer.trackTitle : "Playing"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (root.mprisPlayer && root.mprisPlayer.trackArtist) ? root.mprisPlayer.trackArtist : (root.mprisPlayer && root.mprisPlayer.identity ? root.mprisPlayer.identity : "")
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }

                    RowLayout {
                        spacing: 2

                        // Previous
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: prevMprisMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "previous"
                                size: 10
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: prevMprisMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.mprisPlayer) root.mprisPlayer.previous();
                                }
                            }
                        }

                        // Play / Pause
                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: playMprisMouse.containsMouse ? Qt.rgba(1, 1, 1, 1.0) : Qt.rgba(1, 1, 1, 0.85)

                            SvgIcon {
                                anchors.centerIn: parent
                                name: (root.mprisPlayer && root.mprisPlayer.isPlaying) ? "pause" : "play"
                                size: 11
                                color: "#000000"
                            }

                            MouseArea {
                                id: playMprisMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.mprisPlayer) root.mprisPlayer.togglePlaying();
                                }
                            }
                        }

                        // Next
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: nextMprisMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "next"
                                size: 10
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: nextMprisMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.mprisPlayer) root.mprisPlayer.next();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Separator after MPRIS
        Rectangle {
            visible: root.mprisPlayer !== null
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
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
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
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
                        name: modelData.icon || "chevron-right"
                        size: 13
                        color: actionMouse.containsMouse ? Theme.accentCyan : Theme.textSecondary
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
                            if (modelData.execute) {
                                modelData.execute();
                            }
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
        // New Window button (hidden if native desktopActions already contains New Window)
        Rectangle {
            visible: !root.desktopActions.some(function(act) {
                let nm = (act.name || "").toLowerCase();
                return nm === "new window" || nm === "new-window" || nm === "new window...";
            })
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
                    if (root.appData) DockService.newWindow(root.appData);
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
                    if (root.appData) {
                        if (root.isPinned) {
                            DockService.unpinApp(root.appData.id);
                        } else {
                            DockService.pinApp(root.appData);
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
                    if (root.appData) DockService.quitApp(root.appData);
                    root.isOpen = false;
                    root.closed();
                }
            }
        }
    }
}
