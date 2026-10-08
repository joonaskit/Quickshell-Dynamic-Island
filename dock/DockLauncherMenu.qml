import ".."
import QtQuick

// Right-click menu of the launcher's dock button: the launcher's settings as
// quick controls, and a link to its full settings page. Like the launcher, it
// grows out of the corner by that button.
Item {
    id: root

    property bool isOpen: false
    property real dockCapsuleX: 0
    property real dockCapsuleY: 0
    property real dockCapsuleWidth: 0
    property real dockCapsuleHeight: 0
    property bool isVertical: false
    property string dockPosition: "bottom"

    // How far open the menu is (0 to 1), and the current radius of the dock
    // corner it sits on; the dock straightens that corner as the menu opens
    readonly property real openProgress: geo.progress
    property real dockCornerRadius: Theme.dockRadius

    DockFlyoutGeometry {
        id: geo
        open: root.isOpen
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: root.dockCapsuleX
        dockCapsuleY: root.dockCapsuleY
        dockCapsuleWidth: root.dockCapsuleWidth
        dockCapsuleHeight: root.dockCapsuleHeight
        align: "start"
        finalWidth: 290
        finalHeight: menuColumn.implicitHeight + 16
        parentWidth: root.parent ? root.parent.width : 500
        parentHeight: root.parent ? root.parent.height : 500
    }

    visible: geo.progress > 0.001
    opacity: Math.min(1.0, geo.progress * 4)

    x: geo.x
    y: geo.y
    width: geo.width
    height: geo.height

    DockFlyoutBackground {
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        filletSize: geo.filletSize
        cornerRadius: 12
        startFlush: geo.startFlush
        dockCornerRadius: root.dockCornerRadius
        farFillet: geo.farFillet
        farOverhang: geo.farOverhang
    }

    // A label with a row of mutually exclusive options
    component SegmentedRow: Item {
        id: segRow

        property string label: ""
        // [{ label, value }]
        property var options: []
        property var currentValue
        signal selected(var value)

        height: 30

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: segRow.label
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textPrimary
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 176
            height: 24
            radius: 7
            color: Qt.rgba(1, 1, 1, 0.06)

            Row {
                anchors.fill: parent
                anchors.margins: 2

                Repeater {
                    model: segRow.options

                    delegate: Rectangle {
                        id: segOption

                        required property var modelData
                        readonly property bool isSelected: segRow.currentValue === modelData.value

                        width: parent.width / segRow.options.length
                        height: parent.height
                        radius: 5
                        color: isSelected ? Theme.accent : (segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: segOption.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: segOption.isSelected ? Font.DemiBold : Font.Normal
                            color: segOption.isSelected ? Theme.accentForeground : Theme.textSecondary
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: segRow.selected(segOption.modelData.value)
                        }
                    }
                }
            }
        }
    }

    // A label with an on / off switch; the whole row is clickable
    component ToggleRow: Rectangle {
        id: toggleRow

        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        height: 30
        radius: 6
        color: toggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: toggleRow.label
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textPrimary
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 18
            radius: 9
            color: toggleRow.checked ? Theme.accentGreen : Theme.switchTrackOff

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                x: toggleRow.checked ? 16 : 2
                y: 2
                width: 14
                height: 14
                radius: 7
                color: Theme.sliderHandle

                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRow.toggled(!toggleRow.checked)
        }
    }

    // Content is clipped to the body so it is revealed as the menu grows
    Item {
        anchors.fill: parent
        clip: true

        Column {
            id: menuColumn
            x: geo.contentX + 8
            y: geo.contentY + 8
            // Fixed width so content doesn't reflow while the menu is still growing
            width: geo.finalWidth - 16
            spacing: 3
            opacity: geo.contentOpacity

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Launcher"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }
            }

            SegmentedRow {
                width: parent.width
                label: "View"
                options: [
                    { "label": "Grid", "value": "grid" },
                    { "label": "List", "value": "list" }
                ]
                currentValue: SettingsService.launcherDefaultView
                onSelected: function(value) {
                    SettingsService.setSetting("launcherDefaultView", value);
                }
            }

            SegmentedRow {
                width: parent.width
                label: "Open on"
                options: [
                    { "label": "All", "value": "All" },
                    { "label": "Recent", "value": "Recent" },
                    { "label": "Frequent", "value": "Frequent" }
                ]
                currentValue: SettingsService.launcherStartTab
                onSelected: function(value) {
                    SettingsService.setSetting("launcherStartTab", value);
                }
            }

            SegmentedRow {
                width: parent.width
                label: "Density"
                options: [
                    { "label": "Comfortable", "value": "comfortable" },
                    { "label": "Compact", "value": "compact" }
                ]
                currentValue: SettingsService.launcherDensity
                onSelected: function(value) {
                    SettingsService.setSetting("launcherDensity", value);
                }
            }

            SegmentedRow {
                width: parent.width
                label: "Columns"
                options: [
                    { "label": "3", "value": 3 },
                    { "label": "4", "value": 4 },
                    { "label": "5", "value": 5 }
                ]
                currentValue: SettingsService.launcherGridColumns
                onSelected: function(value) {
                    SettingsService.setSetting("launcherGridColumns", value);
                }
            }

            ToggleRow {
                width: parent.width
                label: "Category bar"
                checked: SettingsService.launcherShowCategories
                onToggled: function(value) {
                    SettingsService.setSetting("launcherShowCategories", value);
                }
            }

            ToggleRow {
                width: parent.width
                label: "App subtitles"
                checked: SettingsService.launcherShowGenericNames
                onToggled: function(value) {
                    SettingsService.setSetting("launcherShowGenericNames", value);
                }
            }

            // Hairline separator
            Rectangle {
                width: parent.width - 12
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Rectangle {
                width: parent.width
                height: 30
                radius: 6
                color: settingsLinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                SvgIcon {
                    id: settingsLinkIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "settings"
                    size: 13
                    color: Theme.textSecondary
                }

                Text {
                    anchors.left: settingsLinkIcon.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Launcher Settings…"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: settingsLinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        SettingsService.requestOpenSettings("Launcher");
                        root.isOpen = false;
                    }
                }
            }
        }
    }
}
