import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

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

    width: 260
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
        color: Theme.dockTransparent ? Qt.rgba(0.12, 0.13, 0.16, 0.94) : "#1c1c1e"
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

        // Header
        RowLayout {
            width: parent.width
            height: 26
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 6
                color: Qt.rgba(10/255, 132/255, 255/255, 0.2)

                SvgIcon {
                    anchors.centerIn: parent
                    name: "folder"
                    size: 13
                    color: Theme.accentBlue
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Downloads & Recent Files"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                SvgIcon {
                    anchors.centerIn: parent
                    name: "rotate-cw"
                    size: 11
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DownloadsService.refresh()
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

        // Empty state
        Item {
            width: parent.width
            height: 36
            visible: (!DownloadsService.recentFiles || DownloadsService.recentFiles.length === 0)

            Text {
                anchors.centerIn: parent
                text: "No recent files"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }

        // Recent Files Repeater
        Repeater {
            model: DownloadsService.recentFiles ? DownloadsService.recentFiles.slice(0, 7) : []

            delegate: Rectangle {
                id: fileItem
                width: parent.width
                height: 34
                radius: 8
                color: fileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // File icon
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 5
                        color: Qt.rgba(1, 1, 1, 0.06)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: modelData.isDir ? "folder" : "file"
                            size: 13
                            color: modelData.isDir ? Theme.accentBlue : Theme.textSecondary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || "File"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.size || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        DownloadsService.openFile(modelData.path);
                        root.isOpen = false;
                        root.closed();
                    }
                }
            }
        }

        // Separator before bottom action
        Rectangle {
            width: parent.width - 12
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // Open in File Manager button
        Rectangle {
            width: parent.width
            height: 28
            radius: 7
            color: openFolderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                SvgIcon {
                    name: "folder"
                    size: 13
                    color: Theme.accentBlue
                }

                Text {
                    Layout.fillWidth: true
                    text: "Open Downloads Folder"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: openFolderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DownloadsService.openFolder();
                    root.isOpen = false;
                    root.closed();
                }
            }
        }
    }
}

