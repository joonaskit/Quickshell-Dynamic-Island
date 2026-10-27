import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // What the compact island shows besides the clock
    SettingsSection {
        key: "compact"
        title: "COMPACT ISLAND"
        subtitle: "What the island shows while closed"

        SettingToggle {
            title: "Media Playing"
            keywords: "music song player compact pill"
            description: "The playing song or video"
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
            keywords: "stopwatch countdown compact pill"
            description: "A running timer or stopwatch"
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
            keywords: "progress compact pill"
            description: "Progress from other apps, such as file copies"
            iconName: "download"
            iconColor: Theme.accentGreen
            checked: SettingsService.showActivitiesInPill
            onToggled: function(val) {
                SettingsService.setSetting("showActivitiesInPill", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            readonly property bool shown: SettingsService.showActivitiesInPill || SettingsService.isWidgetEnabled("activities")
            title: "Show File Copy Progress"
            keywords: "kio dolphin move copy progress"
            description: shown ? "Copies and moves from Dolphin and other KDE apps, in place of their own progress window"
                               : "Turn on App Activities, in the island or as a card, to use this"
            iconName: "download"
            iconColor: Theme.accentGreen
            isSubOption: true
            enabled: shown
            checked: SettingsService.kioJobActivities
            onToggled: function(val) {
                SettingsService.setSetting("kioJobActivities", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Volume & Brightness Level"
            keywords: "osd indicator popup"
            description: "A level bar when they are changed with the shell's shortcuts"
            iconName: "volume-high"
            iconColor: Theme.accentBlue
            checked: SettingsService.showOsd
            onToggled: function(val) {
                SettingsService.setSetting("showOsd", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Desktop Switch"
            keywords: "virtual desktop osd indicator workspace"
            description: "The new virtual desktop for a moment after a switch"
            iconName: "desktop"
            iconColor: Theme.accentPurple
            checked: SettingsService.showDesktopOsd
            onToggled: function(val) {
                SettingsService.setSetting("showDesktopOsd", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Notification Bubble"
            keywords: "detached circle unread"
            description: "A small circle beside the island while there are unread notifications"
            iconName: "bell"
            iconColor: Theme.accentOrange
            checked: SettingsService.showDetachedNotifBubble
            onToggled: function(val) {
                SettingsService.setSetting("showDetachedNotifBubble", val);
            }
        }
    }

    // Cards of the expanded island
    SettingsSection {
        key: "cards"
        title: "EXPANDED ISLAND CARDS"
        subtitle: "Top to bottom"

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
                    SettingMoveButtons {
                        visible: !SettingsSearch.active
                        Layout.rightMargin: 10
                        canMoveUp: SettingsService.canMoveWidget(widgetRow.modelData.id, -1)
                        canMoveDown: SettingsService.canMoveWidget(widgetRow.modelData.id, 1)
                        onMoved: function(delta) {
                            SettingsService.moveWidget(widgetRow.modelData.id, delta);
                        }
                    }
                }
            }
        }

        SettingDivider {}

        SettingSegmented {
            title: "Collapse After"
            keywords: "auto collapse timeout close expanded island"
            description: "How long the expanded island stays open without the pointer over it"
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

    // Clock
    SettingsSection {
        key: "clock"
        title: "CLOCK"

        SettingToggle {
            title: "24-Hour Time"
            keywords: "clock format am pm"
            description: "Show 14:00 instead of 2:00 PM"
            iconName: "clock"
            iconColor: Theme.accentBlue
            checked: SettingsService.use24Hour
            onToggled: function(val) {
                SettingsService.setSetting("use24Hour", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Seconds in Expanded Island"
            keywords: "clock seconds"
            description: "Show seconds next to the time when the island is open"
            iconName: "clock"
            iconColor: Theme.accentPurple
            checked: SettingsService.showSeconds
            onToggled: function(val) {
                SettingsService.setSetting("showSeconds", val);
            }
        }
    }
}
