import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real volume: AudioService.volume
    property bool isMuted: AudioService.isMuted

    implicitHeight: Theme.px(34)
    implicitWidth: parent ? parent.width : Theme.px(370)

    RowLayout {
        anchors.fill: parent
        spacing: Theme.px(10)

        // Speaker / Mute Toggle Button
        Rectangle {
            Layout.preferredWidth: Theme.px(28)
            Layout.preferredHeight: Theme.px(28)
            radius: Theme.px(14)
            color: muteMouse.containsMouse ? Theme.controlBackgroundHover : "transparent"

            SvgIcon {
                anchors.centerIn: parent
                name: {
                    if (root.isMuted || root.volume <= 0.01) return "volume-mute";
                    if (root.volume < 0.5) return "volume-low";
                    return "volume-high";
                }
                size: Theme.px(16)
                color: root.isMuted ? Theme.accentRed : Theme.textPrimary
            }

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    AudioService.toggleMute();
                }
            }
        }

        // Slider Track Container with comfortable hit area
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(32)

            Rectangle {
                id: sliderTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.px(18)
                radius: Theme.px(9)
                color: Theme.sliderTrack
                clip: true

                // Volume Fill
                Rectangle {
                    id: sliderFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: Theme.px(9)
                    color: root.isMuted ? Theme.textTertiary : (dragArea.containsMouse || dragArea.pressed ? Theme.accentBlue : Theme.sliderFill)
                    width: Math.max(0, Math.min(sliderTrack.width, (root.isMuted ? 0 : root.volume) * sliderTrack.width))

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function updateVolume(mouseX) {
                    let newVol = Math.max(0, Math.min(1.0, mouseX / sliderTrack.width));
                    AudioService.setVolume(newVol);
                }

                onPressed: function(mouse) {
                    releaseTimer.stop();
                    AudioService.isChanging = true;
                    updateVolume(mouse.x);
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        updateVolume(mouse.x);
                    }
                }

                onReleased: {
                    releaseTimer.restart();
                }

                onWheel: function(wheel) {
                    let step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    AudioService.setVolume(root.volume + step);
                }
            }

            Timer {
                id: releaseTimer
                interval: 250
                onTriggered: {
                    AudioService.isChanging = false;
                }
            }
        }

        // Percentage readout
        Text {
            id: percentText
            Layout.preferredWidth: Theme.px(38)
            text: root.isMuted ? "Mute" : Math.round(root.volume * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: root.isMuted ? Theme.accentRed : Theme.textSecondary
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
