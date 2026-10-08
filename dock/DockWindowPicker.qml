import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var appData: null
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

    // True while the pointer is over the list, so the dock keeps it open
    readonly property bool hovered: pickerHover.hovered

    HoverHandler {
        id: pickerHover
    }

    readonly property var windowList: (appData && DockService) ? DockService.findToplevels(appData) : []

    // The list is an extension of the dock: it grows out of the hovered icon
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
        finalWidth: 240
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

    // Content is clipped to the body so it is revealed as the list grows
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
                    color: Theme.accentTint(0.2)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.windowList.length + " open"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }
                }
            }

            // Hairline separator
            Rectangle {
                width: parent.width - 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Theme.overlay(0.08)
            }

            // List of Windows
            Repeater {
                model: root.windowList

                delegate: Rectangle {
                    id: rowItem
                    width: parent.width
                    height: 32
                    radius: 8
                    color: rowHover.hovered ? Theme.overlay(0.12) : (modelData.activated ? Theme.accentTint(0.12) : "transparent")

                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Passive, so hovering the close button still counts as hovering the row
                    HoverHandler {
                        id: rowHover
                    }

                    // Declared before the row content so the close button sits above it
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.MiddleButton) {
                                DockService.closeWindow(modelData);
                                return;
                            }
                            DockService.activateWindow(modelData);
                            root.isOpen = false;
                            root.closed();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // App icon with an active indicator dot
                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20

                            Image {
                                anchors.fill: parent
                                source: root.appData ? DockService.resolveIcon(root.appData.icon) : ""
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                opacity: modelData.minimized ? 0.45 : 1.0
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: 7
                                height: 7
                                radius: 3.5
                                color: Theme.accent
                                border.width: 1
                                border.color: Theme.cardBackground
                                visible: modelData.activated
                            }
                        }

                        // Window title
                        Text {
                            Layout.fillWidth: true
                            text: (modelData.title && modelData.title.trim().length > 0) ? modelData.title : (root.appData ? (root.appData.name + " (" + (index + 1) + ")") : ("Window " + (index + 1)))
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: modelData.activated ? Font.DemiBold : Font.Normal
                            color: modelData.activated ? Theme.accent : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        // State badge for windows that are not directly visible
                        Rectangle {
                            visible: modelData.minimized || modelData.onCurrent === false
                            Layout.preferredHeight: 16
                            Layout.preferredWidth: stateText.implicitWidth + 10
                            radius: 8
                            color: Theme.overlay(0.08)

                            Text {
                                id: stateText
                                anchors.centerIn: parent
                                text: modelData.minimized ? "Minimized" : "Other desktop"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: Theme.textSecondary
                            }
                        }

                        // Close Window button
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: closeBtnMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.3) : "transparent"
                            opacity: rowHover.hovered ? 1.0 : 0.0

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
                                    DockService.closeWindow(modelData);
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
