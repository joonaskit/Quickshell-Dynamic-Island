import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    readonly property color nightColor: Theme.accentOrange
    implicitWidth: embedded ? (parent ? parent.width : Theme.px(340)) : Theme.px(320)
    implicitHeight: mainCard.height

    Rectangle {
        id: cardShadow
        anchors.centerIn: mainCard
        width: mainCard.width + Theme.px(16)
        height: mainCard.height + Theme.px(12)
        radius: mainCard.radius + Theme.px(4)
        color: Theme.islandShadow
        opacity: 0.7
        visible: !root.embedded
    }

    Rectangle {
        id: mainCard
        width: root.embedded ? (root.parent ? root.parent.width : root.width) : root.implicitWidth
        height: contentColumn.implicitHeight + (root.embedded ? Theme.px(14) : Theme.px(28))
        radius: root.embedded ? 0 : Theme.px(18)
        color: root.embedded ? "transparent" : Theme.cardBackground
        border.width: root.embedded ? 0 : 1
        border.color: Theme.overlay(0.12)
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.embedded ? Theme.px(10) : Theme.px(14)
            spacing: Theme.px(12)

            // Header: badge, status and on/off button
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: NightLightService.running ? Qt.rgba(255/255, 159/255, 10/255, 0.22) : Theme.cardBackgroundHover
                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "moon"
                        size: Theme.px(20)
                        color: NightLightService.running ? root.nightColor : Theme.textTertiary
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "Night Light"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (!NightLightService.available) return "Not available in this session";
                            if (!NightLightService.switchedOn) return "Off";
                            if (NightLightService.custom) {
                                if (NightLightService.inWindow) return "Tinting until " + NightLightService.scheduleEnd;
                                return "On, starts at " + NightLightService.scheduleStart;
                            }
                            if (NightLightService.running) return "Tinting at " + NightLightService.currentTemperature + " K";
                            return NightLightService.daylight ? "On, waiting for the evening" : "On";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: NightLightService.running ? root.nightColor : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    visible: NightLightService.available
                    Layout.preferredWidth: Theme.px(64)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(14)
                    color: NightLightService.switchedOn ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : Theme.overlay(0.1)
                    scale: powerMouse.pressed ? 0.92 : (powerMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: NightLightService.switchedOn ? "ON" : "OFF"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: NightLightService.switchedOn ? root.nightColor : Theme.textSecondary
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NightLightService.setActive(!NightLightService.switchedOn)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.overlay(0.08)
                visible: NightLightService.available
            }

            // Night temperature slider: warm on the left
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: NightLightService.available

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "NIGHT TEMPERATURE"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: NightLightService.nightTemperature + " K"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.DemiBold
                        color: root.nightColor
                    }
                }

                Rectangle {
                    id: track
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(14)
                    color: Theme.overlay(0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(track.height, track.width * (NightLightService.nightTemperature - NightLightService.minTemperature)
                                        / (NightLightService.maxTemperature - NightLightService.minTemperature))
                        radius: Theme.corner(14)
                        color: root.nightColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        // Rounded to 100 K steps
                        function kelvinAt(mouse) {
                            let norm = Math.max(0.0, Math.min(1.0, mouse.x / track.width));
                            let range = NightLightService.maxTemperature - NightLightService.minTemperature;
                            return Math.round((NightLightService.minTemperature + norm * range) / 100) * 100;
                        }

                        onPressed: (mouse) => NightLightService.previewTemperature(kelvinAt(mouse))
                        onPositionChanged: (mouse) => {
                            if (pressed) NightLightService.previewTemperature(kelvinAt(mouse));
                        }
                        onReleased: (mouse) => NightLightService.commitTemperature(kelvinAt(mouse))
                    }
                }
            }

            // Schedule: sunrise/sunset or all day
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: NightLightService.available

                Text {
                    text: "SCHEDULE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(8)

                    Repeater {
                        model: [
                            { label: "SUNSET", value: "DarkLight" },
                            { label: "CUSTOM", value: "Custom" },
                            { label: "ALWAYS ON", value: "Constant" }
                        ]

                        Rectangle {
                            readonly property bool selected: NightLightService.shownMode === modelData.value

                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(28)
                            radius: Theme.px(14)
                            color: selected ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : (modeMouse.containsMouse ? Theme.overlay(0.1) : Theme.overlay(0.06))
                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.Bold
                                color: selected ? root.nightColor : Theme.textSecondary
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NightLightService.setMode(modelData.value)
                            }
                        }
                    }
                }

                // Hours for the custom schedule
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(8)
                    visible: NightLightService.custom

                    Repeater {
                        model: [
                            { label: "FROM", which: "start" },
                            { label: "TO", which: "end" }
                        ]

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.px(6)

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.DemiBold
                                color: Theme.textTertiary
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(28)
                                radius: Theme.corner(8)
                                color: Theme.overlay(0.05)
                                border.width: 1
                                border.color: timeInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                                TextInput {
                                    id: timeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(10)
                                    anchors.rightMargin: Theme.px(10)
                                    verticalAlignment: TextInput.AlignVCenter
                                    horizontalAlignment: TextInput.AlignHCenter
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontPx(12)
                                    color: Theme.textPrimary
                                    selectionColor: Theme.accentTint(0.4)
                                    selectedTextColor: Theme.textPrimary
                                    inputMask: "99:99"
                                    selectByMouse: true
                                    text: modelData.which === "start" ? NightLightService.scheduleStart : NightLightService.scheduleEnd

                                    // Bad input snaps back to the saved time
                                    function commit() {
                                        if (!NightLightService.setScheduleTime(modelData.which, text)) {
                                            text = Qt.binding(() => modelData.which === "start" ? NightLightService.scheduleStart : NightLightService.scheduleEnd);
                                        }
                                    }
                                    onEditingFinished: commit()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
