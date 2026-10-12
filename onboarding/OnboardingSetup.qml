import ".."
import QtQuick
import QtQuick.Layouts

// Step 4: a handful of starting choices. Each one is an ordinary setting, applied
// and saved as it is changed, so leaving the guide here loses nothing.
OnboardingPage {
    title: "Choose a setup"
    intro: "A few choices to start with. They apply at once, and all of them, with many more, are in Settings."

    SettingsSection {
        title: "CLOCK AND SIZE"

        SettingSegmented {
            title: "Clock"
            description: "How the time is shown"
            iconName: "clock"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.use24Hour
            options: [
                { label: "24-hour", value: true },
                { label: "12-hour", value: false }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("use24Hour", val);
            }
        }

        SettingDivider {}

        SettingSlider {
            title: "Interface size"
            description: "Size of the island, the dock and the popups"
            iconName: "sliders"
            iconColor: Theme.accentCyan
            value: SettingsService.uiScale
            minimumValue: 0.80
            maximumValue: 1.25
            stepSize: 0.05
            onValueModified: function(val) {
                SettingsService.setSetting("uiScale", val);
            }
        }

        SettingDivider {}

        SettingSlider {
            title: "Text size"
            description: "Size of the clock, labels and other text"
            iconName: "type"
            iconColor: Theme.accentYellow
            value: SettingsService.fontScale
            minimumValue: 0.85
            maximumValue: 1.25
            stepSize: 0.05
            onValueModified: function(val) {
                SettingsService.setSetting("fontScale", val);
            }
        }
    }

    SettingsSection {
        title: "DOCK"

        SettingSegmented {
            title: "Dock position"
            description: "The screen edge the dock sits on"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.dockPosition
            options: [
                { label: "Bottom", value: "bottom" },
                { label: "Left", value: "left" },
                { label: "Right", value: "right" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("dockPosition", val);
            }
        }
    }

    SettingsSection {
        title: "STATUS ICONS"
        subtitle: "Shown at the top right. The power and battery icon is always there"

        // The system icons as chips: tap one to show or hide it. The battery icon is left
        // out: it opens the power menu, the only place to shut down or restart
        Flow {
            Layout.fillWidth: true
            Layout.margins: Theme.px(12)
            spacing: Theme.px(8)

            Repeater {
                model: StatusIconRegistry.icons.filter(i => i.group === "system" && i.id !== "battery")

                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: SettingsService[modelData.settingKey] === true

                    width: chipRow.implicitWidth + Theme.px(20)
                    height: Theme.px(28)
                    radius: height / 2
                    color: chip.on ? Theme.accentTint(0.28) : Theme.overlay(0.06)
                    border.width: 1
                    border.color: chip.on ? Theme.accentTint(0.6) : Theme.overlay(0.08)
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.px(6)

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: chip.modelData.icon
                            size: Theme.px(12)
                            color: chip.on ? Theme.textPrimary : Theme.textTertiary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.title
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11)
                            color: chip.on ? Theme.textPrimary : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.toggleSetting(chip.modelData.settingKey)
                    }
                }
            }
        }
    }
}
