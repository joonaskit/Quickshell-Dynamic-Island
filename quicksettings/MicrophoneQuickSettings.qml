import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    implicitWidth: embedded ? (parent ? parent.width : 340) : 320
    implicitHeight: mainCard.height

    // Soft Drop Shadow
    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + 16
        height: mainCard.height + 12
        radius: mainCard.radius + 4
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    // Main Control Center Card
    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? 14 : 28)
        radius: root.embedded ? 0 : 18
        color: root.embedded ? "transparent" : Theme.cardBackground
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? 10 : 14
            spacing: 12

            // Top Header: Microphone Badge, Status, and Mute Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Circular Microphone Badge
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: !MicrophoneService.isMuted ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Theme.cardBackgroundHover

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: MicrophoneService.isMuted ? "mic-off" : "mic"
                        size: 20
                        color: !MicrophoneService.isMuted ? Theme.accentRed : Theme.textTertiary

                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MicrophoneService.toggleMute();
                        }
                    }
                }

                // Title & Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: MicrophoneService.isMuted ? "Microphone Muted" : "Microphone Active"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: MicrophoneService.defaultSource || "Default Input"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Mute / Unmute Button
                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 28
                    radius: 14
                    color: MicrophoneService.isMuted ? Qt.rgba(255/255, 69/255, 58/255, 0.25) : Theme.overlay(0.1)
                    scale: toggleMouse.pressed ? 0.92 : (toggleMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: MicrophoneService.isMuted ? "UNMUTE" : "MUTE"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: MicrophoneService.isMuted ? Theme.accentRed : Theme.textSecondary
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MicrophoneService.toggleMute();
                        }
                    }
                }
            }

            // Hairline Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
            }

            // Input Volume Slider
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "INPUT LEVEL"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Math.round(MicrophoneService.volume * 100) + "%"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: MicrophoneService.isMuted ? Theme.textTertiary : Theme.accentRed
                    }
                }

                // Rounded Slider Track
                Rectangle {
                    id: sliderTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 14
                    color: Theme.overlay(0.08)

                    // Fill bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(sliderTrack.height, sliderTrack.width * MicrophoneService.volume)
                        radius: Theme.corner(14)
                        color: MicrophoneService.isMuted ? Theme.overlay(0.2) : Theme.accentRed

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Icon inside slider
                    SvgIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: MicrophoneService.isMuted ? "mic-off" : "mic"
                        size: 14
                        color: Theme.dangerForeground
                    }

                    MouseArea {
                        id: sliderMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        function updateFromPosition(mouse) {
                            let norm = Math.max(0.0, Math.min(1.0, mouse.x / sliderTrack.width));
                            MicrophoneService.setVolume(norm);
                            if (MicrophoneService.isMuted && norm > 0) {
                                MicrophoneService.setMute(false);
                            }
                        }

                        onPressed: (mouse) => updateFromPosition(mouse)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateFromPosition(mouse);
                        }
                    }
                }
            }

            // Device list (if multiple sources exist)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                opacity: MicrophoneService.sources.length > 1 ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                Text {
                    text: "INPUT DEVICES"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                Repeater {
                    model: MicrophoneService.sources

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Theme.corner(8)
                        color: modelData.isDefault ? Qt.rgba(255/255, 69/255, 58/255, 0.18) : (sourceMouse.containsMouse ? Theme.overlay(0.06) : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            SvgIcon {
                                name: "mic"
                                size: 12
                                color: modelData.isDefault ? Theme.accentRed : Theme.textTertiary
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }

                            Text {
                                text: modelData.displayName
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                                color: modelData.isDefault ? Theme.accentRed : Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
                            }

                            SvgIcon {
                                name: "check"
                                size: 12
                                color: Theme.accentRed
                                opacity: modelData.isDefault ? 1.0 : 0.0
                                scale: modelData.isDefault ? 1.0 : 0.5
                                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot } }
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MicrophoneService.setSource(modelData.name);
                            }
                        }
                    }
                }
            }
        }
    }
}
