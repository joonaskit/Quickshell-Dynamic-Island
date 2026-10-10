import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property real brightness: BrightnessService.brightness

    implicitHeight: Theme.px(34)
    implicitWidth: parent ? parent.width : Theme.px(370)

    RowLayout {
        anchors.fill: parent
        spacing: Theme.px(10)

        // Brightness Icon
        Rectangle {
            Layout.preferredWidth: Theme.px(28)
            Layout.preferredHeight: Theme.px(28)
            radius: Theme.px(14)
            color: "transparent"

            SvgIcon {
                anchors.centerIn: parent
                name: root.brightness < 0.5 ? "brightness-low" : "brightness-high"
                size: Theme.px(16)
                color: Theme.accentOrange
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

                // Brightness Fill
                Rectangle {
                    id: sliderFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: Theme.cornerPx(9)
                    color: (dragArea.containsMouse || dragArea.pressed) ? Theme.accentOrange : Theme.sliderFill
                    width: Math.max(0, Math.min(sliderTrack.width, root.brightness * sliderTrack.width))

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

                function updateBrightness(mouseX) {
                    let newBright = Math.max(0.01, Math.min(1.0, mouseX / sliderTrack.width));
                    BrightnessService.setBrightness(newBright);
                }

                onPressed: function(mouse) {
                    releaseTimer.stop();
                    BrightnessService.isChanging = true;
                    updateBrightness(mouse.x);
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        updateBrightness(mouse.x);
                    }
                }

                onReleased: {
                    releaseTimer.restart();
                }

                onWheel: function(wheel) {
                    let step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    BrightnessService.setBrightness(root.brightness + step);
                }
            }

            Timer {
                id: releaseTimer
                interval: 250
                onTriggered: {
                    BrightnessService.isChanging = false;
                }
            }
        }

        // Percentage readout
        Text {
            id: percentText
            Layout.preferredWidth: Theme.px(38)
            text: Math.round(root.brightness * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
