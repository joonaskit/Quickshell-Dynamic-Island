import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Expanded Island Cards Customization
    SettingsSection {
        title: "EXPANDED ISLAND CARDS"
        subtitle: "Choose and order the cards shown when expanded"

        // One row per registered widget, in display order: cards, then controls
        Repeater {
            model: SettingsService.orderedWidgets.filter(w => w.group === "cards").concat(SettingsService.orderedWidgets.filter(w => w.group === "controls"))

            delegate: ColumnLayout {
                id: widgetRow
                required property var modelData
                required property int index
                readonly property bool matchesSearch: widgetToggle.matchesSearch

                Layout.fillWidth: true
                visible: matchesSearch
                spacing: 0

                SettingDivider {
                    visible: widgetRow.index > 0 && !SettingsSearch.active
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SettingToggle {
                        id: widgetToggle
                        title: widgetRow.modelData.title
                        description: widgetRow.modelData.description
                        iconName: widgetRow.modelData.icon
                        iconColor: widgetRow.modelData.iconColor
                        checked: SettingsService.isWidgetEnabled(widgetRow.modelData.id)
                        onToggled: function(val) {
                            SettingsService.setWidgetEnabled(widgetRow.modelData.id, val);
                        }
                    }

                    // Move up / down within the widget's group
                    Repeater {
                        model: [
                            { "icon": "chevron-up", "delta": -1 },
                            { "icon": "chevron-down", "delta": 1 }
                        ]

                        delegate: Rectangle {
                            id: moveButton
                            required property var modelData
                            readonly property bool canMove: SettingsService.canMoveWidget(widgetRow.modelData.id, modelData.delta)

                            visible: !SettingsSearch.active
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.rightMargin: modelData.delta > 0 ? 10 : 2
                            radius: Theme.corner(7)
                            color: moveMouse.pressed ? Theme.overlay(0.16) : (moveMouse.containsMouse ? Theme.overlay(0.1) : "transparent")
                            opacity: canMove ? 1.0 : 0.25

                            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                            SvgIcon {
                                anchors.centerIn: parent
                                name: moveButton.modelData.icon
                                size: 14
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: moveMouse
                                anchors.fill: parent
                                enabled: moveButton.canMove
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.moveWidget(widgetRow.modelData.id, moveButton.modelData.delta)
                            }
                        }
                    }
                }
            }
        }
    }

    // Island Behavior & Timing
    SettingsSection {
        title: "ISLAND BEHAVIOR & TIMING"
        subtitle: "Morphing, full-screen & auto-collapse"

        // 1. Show Media When Playing
        SettingToggle {
            title: "Show Media Playing in Compact Pill"
            description: "Morphs compact pill into media status when music or audio is playing"
            iconName: "music"
            iconColor: Theme.accentRed
            checked: SettingsService.showMediaWhenPlaying
            onToggled: function(val) {
                SettingsService.setSetting("showMediaWhenPlaying", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Timer in Island"
            description: "Show a running timer or stopwatch in the compact island"
            iconName: "clock"
            iconColor: Theme.accentOrange
            checked: SettingsService.showTimerInPill
            onToggled: function(val) {
                SettingsService.setSetting("showTimerInPill", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "App Activities in Island"
            description: "Show progress from other apps, such as file copies, in the compact island"
            iconName: "download"
            iconColor: Theme.accentGreen
            checked: SettingsService.showActivitiesInPill
            onToggled: function(val) {
                SettingsService.setSetting("showActivitiesInPill", val);
            }
        }

        SettingDivider {}

        // 2. Morph to Top Bar When Maximized
        SettingToggle {
            title: "Morph to Top Bar When Windows Maximized"
            description: "Liquidly flattens the island into a full-width GNOME-style top bar"
            iconName: "window"
            iconColor: Theme.accentBlue
            checked: SettingsService.morphToTopBarWhenMaximized
            onToggled: function(val) {
                SettingsService.setSetting("morphToTopBarWhenMaximized", val);
            }
        }

        SettingDivider {}

        // 2b. Reserve Space When Maximized Sub-Toggle
        SettingToggle {
            title: "Reserve Top Bar Space When Maximized"
            description: "Reserves screen space so maximized windows sit underneath the top bar"
            iconName: "maximize"
            iconColor: Theme.accentCyan
            isSubOption: true
            enabled: SettingsService.morphToTopBarWhenMaximized
            checked: SettingsService.reserveSpaceWhenMaximized
            onToggled: function(val) {
                SettingsService.setSetting("reserveSpaceWhenMaximized", val);
            }
        }

        SettingDivider {}

        // 3. Auto-Hide Island on Fullscreen
        SettingToggle {
            title: "Auto-Hide Island on Fullscreen"
            description: "Collapses and completely hides the Island when games or fullscreen apps are active"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            checked: SettingsService.hideOnFullscreen
            onToggled: function(val) {
                SettingsService.setSetting("hideOnFullscreen", val);
            }
        }

        SettingDivider {}

        // Volume / brightness OSD
        SettingToggle {
            title: "Volume & Brightness OSD"
            description: "Show a level indicator in the island when changed with the system IPC shortcuts"
            iconName: "volume-high"
            iconColor: Theme.accentBlue
            checked: SettingsService.showOsd
            onToggled: function(val) {
                SettingsService.setSetting("showOsd", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Show Desktop Switch Indicator"
            description: "Show the current virtual desktop in the island for a moment after a switch"
            iconName: "desktop"
            iconColor: Theme.accentPurple
            checked: SettingsService.showDesktopOsd
            onToggled: function(val) {
                SettingsService.setSetting("showDesktopOsd", val);
            }
        }

        SettingDivider {}

        // 4. Auto-Collapse Timeout Segmented Picker
        SettingSegmented {
            title: "Auto-Collapse Inactivity Timeout"
            description: "Duration before expanded island automatically collapses when mouse is idle"
            iconName: "clock"
            iconColor: Theme.accentPurple
            currentValue: SettingsService.autoCollapseTimeout
            options: [
                { "label": "3s", "value": 3000 },
                { "label": "6s", "value": 6000 },
                { "label": "10s", "value": 10000 },
                { "label": "Never", "value": 0 }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("autoCollapseTimeout", val);
            }
        }
    }
}
