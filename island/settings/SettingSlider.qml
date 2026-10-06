import "../.."
import QtQuick
import QtQuick.Layouts

// Reusable Custom Draggable Slider Row with live percentage badge and quick presets
Rectangle {
    id: sliderRow
    Layout.fillWidth: true
    implicitHeight: sliderCol.implicitHeight + 20
    color: "transparent"

    property string title: ""
    property string description: ""
    property string iconName: "sliders"
    property color iconColor: Theme.accentCyan
    property real value: 1.0
    property real minimumValue: 0.8
    property real maximumValue: 1.25
    property real stepSize: 0.05
    property var presets: []
    property string valueDisplay: ""

    signal valueModified(real newValue)

    readonly property real fraction: Math.max(0.0, Math.min(1.0, (value - minimumValue) / (maximumValue - minimumValue)))

    function updateFromPos(mouseX, trackWidth) {
        if (trackWidth <= 0) return;
        let ratio = Math.max(0.0, Math.min(1.0, mouseX / trackWidth));
        let rawVal = minimumValue + ratio * (maximumValue - minimumValue);
        let stepped = Math.round(rawVal / stepSize) * stepSize;
        let finalVal = Math.max(minimumValue, Math.min(maximumValue, Math.round(stepped * 100) / 100));
        sliderRow.valueModified(finalVal);
    }

    ColumnLayout {
        id: sliderCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        // Header Row: Icon, Title & Live Value Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 7
                color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.16)

                SvgIcon {
                    anchors.centerIn: parent
                    name: sliderRow.iconName
                    size: 14
                    color: sliderRow.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: sliderRow.title
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                Text {
                    text: sliderRow.description
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textSecondary
                    Layout.maximumWidth: 340
                    wrapMode: Text.WordWrap
                }
            }

            // Live Value Badge
            Rectangle {
                Layout.preferredWidth: Math.max(50, valueBadgeText.implicitWidth + 16)
                Layout.preferredHeight: 24
                radius: 12
                color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.35)

                Text {
                    id: valueBadgeText
                    anchors.centerIn: parent
                    text: sliderRow.valueDisplay !== "" ? sliderRow.valueDisplay : (Math.round(sliderRow.value * 100) + "%")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: sliderRow.iconColor
                }
            }
        }

        // Draggable Slider Track
        Item {
            id: trackArea
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            // Background Rail
            Rectangle {
                id: railBg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)

                // Active Fill Track
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(radius * 2, trackArea.width * sliderRow.fraction)
                    radius: 3
                    color: sliderRow.iconColor

                    Behavior on width {
                        enabled: !trackMouse.pressed
                        NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Draggable Knob / Thumb
            Rectangle {
                id: thumb
                width: 18
                height: 18
                radius: 9
                color: "#ffffff"
                x: Math.max(0, Math.min(trackArea.width - width, (trackArea.width * sliderRow.fraction) - (width / 2)))
                anchors.verticalCenter: parent.verticalCenter
                scale: trackMouse.pressed ? 1.15 : (trackMouse.containsMouse ? 1.08 : 1.0)

                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.25)

                Behavior on x {
                    enabled: !trackMouse.pressed
                    NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                // Subtle inner glow / shadow
                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: sliderRow.iconColor
                    opacity: trackMouse.pressed ? 0.9 : 0.4

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDurationFast }
                    }
                }
            }

            MouseArea {
                id: trackMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: function(mouse) {
                    sliderRow.updateFromPos(mouse.x + 4, trackArea.width);
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        sliderRow.updateFromPos(mouse.x + 4, trackArea.width);
                    }
                }
            }
        }

        // Quick Preset Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: sliderRow.presets && sliderRow.presets.length > 0

            Repeater {
                model: sliderRow.presets

                Rectangle {
                    id: presetBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 6
                    readonly property bool isSelected: Math.abs(sliderRow.value - modelData.value) <= Math.max(0.01, sliderRow.stepSize * 0.51)
                    color: isSelected ? Qt.rgba(sliderRow.iconColor.r, sliderRow.iconColor.g, sliderRow.iconColor.b, 0.25) : (presetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.width: isSelected ? 1 : 0
                    border.color: isSelected ? sliderRow.iconColor : "transparent"
                    scale: presetMouse.pressed ? 0.94 : (presetMouse.containsMouse ? 1.04 : 1.0)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationTooltip } }
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: presetBtn.isSelected ? Font.Bold : Font.Normal
                        color: presetBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sliderRow.valueModified(modelData.value);
                        }
                    }
                }
            }
        }
    }
}
