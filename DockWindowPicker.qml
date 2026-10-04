import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var appData: null
    property bool isOpen: false
    property real targetX: 0
    property real targetY: 0
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

    readonly property var windowList: (appData && DockService) ? DockService.findToplevels(appData) : []

    width: 240
    height: cardCol.implicitHeight + 16

    x: {
        if (isVertical) {
            return dockPosition === "left" ? (targetX + 14) : (targetX - width - 14);
        }
        return Math.max(8, Math.min(parent.width - width - 8, targetX - width / 2));
    }
    y: {
        if (isVertical) {
            return Math.max(8, Math.min(parent.height - height - 8, targetY - height / 2));
        }
        return targetY - height - 12;
    }

    // Card background
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.dockTransparent ? Qt.rgba(0.12, 0.13, 0.16, 0.92) : "#1c1c1e"
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        // Top subtle highlight edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.22)
        }
    }

    Column {
        id: cardCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 3

        // Header: App name and window count
        RowLayout {
            width: parent.width
            height: 24
            spacing: 6

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: root.appData ? root.appData.name : "Windows"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textSecondary
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredHeight: 18
                Layout.preferredWidth: countText.implicitWidth + 10
                Layout.rightMargin: 4
                radius: 9
                color: Qt.rgba(10/255, 132/255, 255/255, 0.2)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.windowList.length + " open"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.accentBlue
                }
            }
        }

        // Hairline separator
        Rectangle {
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // List of Windows
        Repeater {
            model: root.windowList

            delegate: Rectangle {
                id: rowItem
                width: parent.width
                height: 32
                radius: 8
                color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (modelData.activated ? Qt.rgba(10/255, 132/255, 255/255, 0.12) : "transparent")

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Active dot
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: modelData.activated ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.35)
                    }

                    // Window title
                    Text {
                        Layout.fillWidth: true
                        text: (modelData.title && modelData.title.trim().length > 0) ? modelData.title : (root.appData ? (root.appData.name + " (" + (index + 1) + ")") : ("Window " + (index + 1)))
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: modelData.activated ? Font.DemiBold : Font.Normal
                        color: modelData.activated ? Theme.accentBlue : Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    // Close Window button
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: closeBtnMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.3) : "transparent"
                        opacity: rowMouse.containsMouse ? 1.0 : 0.0

                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 11
                            color: closeBtnMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                        }

                        MouseArea {
                            id: closeBtnMouse
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
                    id: rowMouse
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
    }
}

