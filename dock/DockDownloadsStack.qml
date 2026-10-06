import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool isOpen: false
    property real targetX: 0
    property real targetY: 0
    property real dockCapsuleX: 0
    property real dockCapsuleY: 0
    property real dockCapsuleWidth: 0
    property real dockCapsuleHeight: 0
    property bool isVertical: false
    property string dockPosition: "bottom"

    signal closed()

    // The stack is an extension of the dock: it grows out of the downloads icon
    // with its base flush on the dock edge (no gap).
    DockFlyoutGeometry {
        id: geo
        open: root.isOpen
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: root.dockCapsuleX
        dockCapsuleY: root.dockCapsuleY
        dockCapsuleWidth: root.dockCapsuleWidth
        dockCapsuleHeight: root.dockCapsuleHeight
        targetX: root.targetX
        targetY: root.targetY
        finalWidth: 260
        finalHeight: cardCol.implicitHeight + 16
        parentWidth: root.parent ? root.parent.width : 500
        parentHeight: root.parent ? root.parent.height : 500
    }

    visible: geo.progress > 0.001
    opacity: Math.min(1.0, geo.progress * 4)

    x: geo.x
    y: geo.y
    width: geo.width
    height: geo.height

    DockFlyoutBackground {
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        fitsOnDock: geo.fitsOnDock
        filletSize: geo.filletSize
    }

    // Content is clipped to the body so it is revealed as the stack grows
    Item {
        anchors.fill: parent
        clip: true

        Column {
            id: cardCol
            x: geo.contentX + 8
            y: geo.contentY + 8
            // Fixed width so content doesn't reflow while the card is still growing
            width: geo.finalWidth - 16
            spacing: 3
            opacity: geo.contentOpacity

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
}
