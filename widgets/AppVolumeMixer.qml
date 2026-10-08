import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool expanded: false
    readonly property var streams: AppMixerService.streams

    visible: streams.length > 0
    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: visible ? mixerColumn.implicitHeight : 0

    ColumnLayout {
        id: mixerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(4)

        // Header pill toggling the per-app list
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(26)
            radius: Theme.px(8)
            color: headerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: root.expanded ? Theme.accentTint(0.35) : Qt.rgba(1, 1, 1, 0.08)

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(8)
                anchors.rightMargin: Theme.px(8)
                spacing: Theme.px(7)

                SvgIcon {
                    name: "music"
                    size: Theme.px(12)
                    color: Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: "App volumes"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                Text {
                    text: root.streams.length
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                SvgIcon {
                    name: root.expanded ? "chevron-up" : "chevron-down"
                    size: Theme.px(12)
                    color: root.expanded ? Theme.accent : Theme.textSecondary
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        // One slider row per playing app
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(2)
            visible: root.expanded

            Repeater {
                model: root.streams

                delegate: Item {
                    id: row
                    required property var modelData

                    readonly property var audio: modelData.audio
                    readonly property real vol: audio ? audio.volume : 0
                    readonly property bool muted: audio ? audio.muted : false

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(30)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(4)
                        anchors.rightMargin: Theme.px(4)
                        spacing: Theme.px(8)

                        // App icon, falls back to a speaker; tap to mute
                        Rectangle {
                            Layout.preferredWidth: Theme.px(24)
                            Layout.preferredHeight: Theme.px(24)
                            radius: Theme.px(12)
                            color: muteMouse.containsMouse ? Theme.controlBackgroundHover : "transparent"

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: Theme.px(16)
                                height: Theme.px(16)
                                sourceSize: Qt.size(width * 2, height * 2)
                                source: {
                                    let n = AppMixerService.iconFor(row.modelData);
                                    return n ? Quickshell.iconPath(n, true) : "";
                                }
                                visible: status === Image.Ready
                                opacity: row.muted ? 0.35 : 1.0
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                name: (row.muted || row.vol <= 0.01) ? "volume-mute" : "volume-high"
                                size: Theme.px(14)
                                color: row.muted ? Theme.accentRed : Theme.textSecondary
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AppMixerService.toggleMute(row.modelData)
                            }
                        }

                        Text {
                            Layout.preferredWidth: Theme.px(78)
                            text: AppMixerService.displayName(row.modelData)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            color: row.muted ? Theme.textTertiary : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        // Slider
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(24)

                            Rectangle {
                                id: track
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: Theme.px(8)
                                radius: height / 2
                                color: Theme.sliderTrack

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    radius: height / 2
                                    color: row.muted ? Theme.textTertiary : (drag.containsMouse || drag.pressed ? Theme.accent : Theme.sliderFill)
                                    width: Math.max(0, Math.min(track.width, (row.muted ? 0 : row.vol) * track.width))
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                id: drag
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onPressed: function(mouse) { AppMixerService.setVolume(row.modelData, mouse.x / track.width) }
                                onPositionChanged: function(mouse) { if (pressed) AppMixerService.setVolume(row.modelData, mouse.x / track.width) }
                                onWheel: function(wheel) { AppMixerService.setVolume(row.modelData, row.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)) }
                            }
                        }

                        Text {
                            Layout.preferredWidth: Theme.px(34)
                            text: row.muted ? "Mute" : Math.round(row.vol * 100) + "%"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: row.muted ? Theme.accentRed : Theme.textSecondary
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }
}
