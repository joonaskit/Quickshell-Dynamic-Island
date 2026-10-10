import ".."
import QtQuick
import QtQuick.Layouts

// Everything other apps are currently doing, with their progress and actions.
// The compact island only shows the most important one.
Item {
    id: root

    // Set by the expanded view
    property var host: null

    readonly property int maxRows: 5
    readonly property int hiddenCount: Math.max(0, ActivityService.count - root.maxRows)

    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: column.implicitHeight

    component CardButton: Rectangle {
        id: btn
        property string label: ""
        property color accent: Theme.textSecondary
        signal clicked()

        Layout.preferredHeight: Theme.px(24)
        Layout.preferredWidth: btnLabel.implicitWidth + Theme.px(18)
        radius: height / 2
        color: Qt.rgba(accent.r, accent.g, accent.b, btnMouse.containsMouse ? 0.34 : 0.22)
        scale: btnMouse.pressed ? 0.94 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: btn.label
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(11)
            font.weight: Font.DemiBold
            color: Theme.textPrimary
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(12)

        Repeater {
            model: ActivityService.activities.slice(0, root.maxRows)

            delegate: RowLayout {
                id: row

                required property var modelData
                readonly property color accent: ActivityService.accentFor(modelData.state)
                readonly property bool running: modelData.state === "running"
                readonly property string detail: row.running ? modelData.text : ActivityService.stateLabel(modelData)

                Layout.fillWidth: true
                spacing: Theme.px(10)

                Rectangle {
                    Layout.preferredWidth: Theme.px(36)
                    Layout.preferredHeight: Theme.px(36)
                    Layout.alignment: Qt.AlignTop
                    radius: Theme.px(10)
                    color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.16)

                    ActivityIcon {
                        anchors.centerIn: parent
                        icon: row.modelData.state === "failed" ? "" : row.modelData.icon
                        fallback: row.modelData.state === "failed" ? "alert" : (row.modelData.state === "done" ? "check" : "download")
                        size: Theme.px(22)
                        color: row.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.px(3)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(8)

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            elide: Text.ElideRight
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }

                        Text {
                            visible: row.running && row.modelData.progress !== null && row.modelData.progress >= 0
                            text: Math.round((row.modelData.progress || 0) * 100) + "%"
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Theme.textSecondary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: row.detail !== ""
                        text: row.detail
                        elide: Text.ElideRight
                        maximumLineCount: row.modelData.state === "failed" ? 2 : 1
                        wrapMode: row.modelData.state === "failed" ? Text.Wrap : Text.NoWrap
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontPx(11)
                        color: row.modelData.state === "failed" ? Theme.accentRed : Theme.textSecondary
                    }

                    ActivityProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.px(2)
                        visible: row.running && row.modelData.progress !== null
                        progress: row.modelData.progress === null ? 0 : row.modelData.progress
                        accent: row.accent
                    }

                    RowLayout {
                        Layout.topMargin: Theme.px(3)
                        visible: row.modelData.actions.length > 0 || row.modelData.state !== "running"
                        spacing: Theme.px(6)

                        Repeater {
                            model: row.modelData.actions

                            delegate: CardButton {
                                required property var modelData
                                label: modelData.label
                                accent: modelData.id === "cancel" ? Theme.accentRed : Theme.accentBlue
                                onClicked: ActivityService.invoke(row.modelData.key, modelData.id)
                            }
                        }

                        // Finished ones can be cleared by hand; running ones can only be cancelled by their app
                        CardButton {
                            visible: row.modelData.state !== "running"
                            label: "Dismiss"
                            onClicked: ActivityService.dismiss(row.modelData.key)
                        }
                    }
                }
            }
        }

        Text {
            visible: root.hiddenCount > 0
            text: "+" + root.hiddenCount + " more"
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(11)
            color: Theme.textTertiary
        }
    }
}
