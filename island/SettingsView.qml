import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestBack()
    signal requestClose()

    readonly property real maxAllowedHeight: {
        let scrH = (Screen.height > 0) ? Screen.height : 1080;
        return Math.min(scrH - Theme.px(120), Theme.px(840));
    }

    readonly property real desiredHeight: contentColumn.implicitHeight + bottomGrabberArea.height + Theme.px(28)
    readonly property bool needsScroll: desiredHeight > maxAllowedHeight

    implicitWidth: Theme.px(540)
    implicitHeight: Math.min(desiredHeight, maxAllowedHeight)

    // Smooth scrollable container
    Flickable {
        id: scrollContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomGrabberArea.top
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.needsScroll

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
                if (root.needsScroll) {
                    scrollContainer.contentY = Math.max(0, Math.min(scrollContainer.contentHeight - scrollContainer.height, scrollContainer.contentY - wheel.angleDelta.y));
                    scrollFadeTimer.restart();
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            width: scrollContainer.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 14

            // Top Header: Back Button, Title with Icon, and Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Back Button (returns to Expanded Island View)
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: backMouse.containsMouse ? Theme.cardBackgroundHover : Qt.rgba(1, 1, 1, 0.08)
                    scale: backMouse.pressed ? 0.90 : (backMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "chevron-left"
                        size: 16
                        color: backMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestBack()
                    }
                }

                // Settings Icon & Title
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Qt.rgba(10/255, 132/255, 255/255, 0.22)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "settings"
                            size: 18
                            color: Theme.accentBlue
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Settings"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Preferences & Customization"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }
                }

                // Close Button (dismisses the island completely)
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.2) : "transparent"
                    scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
                        color: closeMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Sections
            DisplaySettings {}
            TopBarSettings {}
            IslandSettings {}
            DockSettings {}
            LauncherSettings {}
            AboutSettings {}
        }
    }

    // Subtle Subtle fading scroll indicator (anchored strictly to card viewport, hidden when idle)
    Item {
        id: scrollTrack
        anchors.top: scrollContainer.top
        anchors.topMargin: 46
        anchors.bottom: scrollContainer.bottom
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        width: 3
        visible: root.needsScroll
        opacity: (scrollContainer.moving || scrollContainer.flicking || scrollFadeTimer.running) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }

        Rectangle {
            id: scrollThumb
            width: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.35)
            y: Math.max(0, Math.min(scrollTrack.height - height, scrollContainer.visibleArea.yPosition * scrollTrack.height))
            height: Math.max(28, scrollContainer.visibleArea.heightRatio * scrollTrack.height)
        }
    }

    Timer {
        id: scrollFadeTimer
        interval: 800
        repeat: false
    }

    // Bottom Grabber Pill
    Item {
        id: bottomGrabberArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20

        Rectangle {
            anchors.centerIn: parent
            width: 38
            height: 4
            radius: 2
            color: grabberMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.25)

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        }

        MouseArea {
            id: grabberMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestClose()
        }
    }
}
