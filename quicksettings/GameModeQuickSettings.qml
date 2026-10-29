import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose()

    property bool embedded: false

    readonly property color gameColor: Theme.accentGreenStrong
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
        color: root.embedded ? "transparent" : Theme.cardSurface
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

            // Header: badge, status and the force switch
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(12)

                Rectangle {
                    Layout.preferredWidth: Theme.px(38)
                    Layout.preferredHeight: Theme.px(38)
                    radius: Theme.px(19)
                    color: GameModeService.active ? Qt.rgba(48/255, 209/255, 88/255, 0.22) : Theme.cardSurfaceHover
                    Behavior on color { ColorAnimation { duration: 180 } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "gamepad"
                        size: Theme.px(20)
                        color: GameModeService.active ? root.gameColor : Theme.textTertiary
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(2)

                    Text {
                        text: "GameMode"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            if (!GameModeService.available) return "Not installed (sudo dnf install gamemode)";
                            if (GameModeService.games.length > 0) return "Active for " + GameModeService.games.length + (GameModeService.games.length === 1 ? " game" : " games");
                            if (GameModeService.forced) return "Forced on";
                            return "Idle";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        color: GameModeService.active ? root.gameColor : Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    visible: GameModeService.available
                    Layout.preferredWidth: Theme.px(64)
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(14)
                    color: GameModeService.forced ? Qt.rgba(48/255, 209/255, 88/255, 0.25) : Theme.overlay(0.1)
                    scale: forceMouse.pressed ? 0.92 : (forceMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: GameModeService.forced ? "ON" : "OFF"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Bold
                        color: GameModeService.forced ? root.gameColor : Theme.textSecondary
                    }

                    MouseArea {
                        id: forceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GameModeService.setForced(!GameModeService.forced)
                    }
                }
            }

            Text {
                visible: GameModeService.available
                Layout.fillWidth: true
                text: "ON applies GameMode without a game, until you switch it off or the shell exits. It raises CPU performance, process priority and GPU settings as set in /etc/gamemode.ini."
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                color: Theme.textTertiary
            }

            // Games GameMode is currently applied to
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)
                visible: GameModeService.games.length > 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.overlay(0.08)
                }

                Text {
                    text: "RUNNING GAMES"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }

                Repeater {
                    model: GameModeService.games

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        Rectangle {
                            Layout.preferredWidth: Theme.px(6)
                            Layout.preferredHeight: Theme.px(6)
                            radius: Theme.px(3)
                            color: root.gameColor
                        }

                        Text {
                            text: modelData.name
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(12)
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "PID " + modelData.pid
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            color: Theme.textTertiary
                        }
                    }
                }
            }
        }
    }
}
