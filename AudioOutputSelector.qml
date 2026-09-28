import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool expanded: false

    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: selectorColumn.implicitHeight

    ColumnLayout {
        id: selectorColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(4)

        // Main selector pill
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(28)
            radius: Theme.px(8)
            color: selectorMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: root.expanded ? Qt.rgba(10/255, 132/255, 255/255, 0.35) : Qt.rgba(1, 1, 1, 0.08)

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(8)
                anchors.rightMargin: Theme.px(8)
                spacing: Theme.px(7)

                // Device Type Icon
                SvgIcon {
                    name: AudioService.currentSinkIcon || "volume-high"
                    size: Theme.px(13)
                    color: Theme.accentBlue
                }

                // Active Device Name
                Text {
                    Layout.fillWidth: true
                    text: AudioService.currentSinkDisplayName || "Audio Output"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                // Dropdown indicator
                SvgIcon {
                    visible: (AudioService.sinks || []).length > 1
                    name: root.expanded ? "chevron-up" : "chevron-down"
                    size: Theme.px(12)
                    color: root.expanded ? Theme.accentBlue : Theme.textSecondary
                }
            }

            MouseArea {
                id: selectorMouse
                anchors.fill: parent
                hoverEnabled: (AudioService.sinks || []).length > 1
                cursorShape: (AudioService.sinks || []).length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if ((AudioService.sinks || []).length > 1) {
                        root.expanded = !root.expanded;
                        if (root.expanded) {
                            AudioService.querySinks();
                        }
                    }
                }
            }
        }

        // Expanded Output List
        ColumnLayout {
            id: sinkListLayout
            Layout.fillWidth: true
            spacing: Theme.px(3)
            visible: root.expanded && (AudioService.sinks || []).length > 1

            Repeater {
                model: AudioService.sinks || []

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(30)
                    radius: Theme.px(7)
                    color: itemMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.1)
                        : (modelData.isDefault ? Qt.rgba(10/255, 132/255, 255/255, 0.16) : Qt.rgba(1, 1, 1, 0.03))
                    border.width: modelData.isDefault ? 1 : 0
                    border.color: modelData.isDefault ? Qt.rgba(10/255, 132/255, 255/255, 0.35) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(8)
                        anchors.rightMargin: Theme.px(8)
                        spacing: Theme.px(8)

                        SvgIcon {
                            name: modelData.icon || "volume-high"
                            size: Theme.px(13)
                            color: modelData.isDefault ? Theme.accentBlue : Theme.textSecondary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.displayName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: modelData.isDefault ? Font.DemiBold : Font.Normal
                            color: modelData.isDefault ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                        }

                        SvgIcon {
                            name: "check"
                            size: Theme.px(12)
                            color: Theme.accentBlue
                            visible: modelData.isDefault
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            AudioService.setDefaultSink(modelData.name);
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
