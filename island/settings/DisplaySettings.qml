import "../.."
import QtQuick

SettingsCategory {

    // Colors
    SettingsSection {
        title: "COLORS"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Appearance"
            description: "Light is experimental"
            iconName: "contrast"
            iconColor: Theme.accentIndigo
            currentValue: SettingsService.colorScheme
            options: [
                { label: "Dark", value: "dark" },
                { label: "Light", value: "light" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("colorScheme", val);
            }
        }

        SettingDivider {}

        SettingSwatches {
            title: "Accent Color"
            description: "Used for selection, focus and active states"
            iconName: "sliders"
            iconColor: Theme.accent
            options: Theme.accentChoices
            currentValue: SettingsService.accentColor
            onSelected: function(val) {
                SettingsService.setSetting("accentColor", val);
            }
        }
    }

    // Shape
    SettingsSection {
        title: "SHAPE"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Corner Roundness"
            description: "How rounded cards, buttons, popups and the dock are. Pills and circles stay round"
            iconName: "sliders"
            iconColor: Theme.accentOrange
            currentValue: SettingsService.cornerStyle
            options: Theme.cornerChoices.map(c => ({ label: c.label, value: c.name }))
            onSelected: function(val) {
                SettingsService.setSetting("cornerStyle", val);
            }
        }
    }

    // Display & Scaling (DPI)
    SettingsSection {
        title: "DISPLAY & SCALING (DPI)"
        subtitle: "Interface & Font Sizing"
        titlePixelSize: Theme.fontPx(10)

        // 1. Interface Scale (DPI)
        SettingSlider {
            title: "Interface Scale (DPI)"
            description: "Scale elements, islands, status bar pills, dock, and popup geometry (80% - 125%)"
            iconName: "sliders"
            iconColor: Theme.accentCyan
            value: SettingsService.uiScale
            minimumValue: 0.80
            maximumValue: 1.25
            stepSize: 0.05
            presets: [
                { label: "80%", value: 0.80 },
                { label: "90%", value: 0.90 },
                { label: "100% (Default)", value: 1.00 },
                { label: "110%", value: 1.10 },
                { label: "125%", value: 1.25 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("uiScale", val);
            }
        }

        SettingDivider {}

        // 2. Text & Font Size Scale
        SettingSlider {
            title: "Text & Font Size"
            description: "Proportionally scale clock digits, labels, titles, and text elements (85% - 125%)"
            iconName: "type"
            iconColor: Theme.accentYellow
            value: SettingsService.fontScale
            minimumValue: 0.85
            maximumValue: 1.25
            stepSize: 0.05
            presets: [
                { label: "85%", value: 0.85 },
                { label: "90%", value: 0.90 },
                { label: "100% (Default)", value: 1.00 },
                { label: "110%", value: 1.10 },
                { label: "125%", value: 1.25 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("fontScale", val);
            }
        }
    }

    // Fonts
    SettingsSection {
        title: "FONTS"
        titlePixelSize: Theme.fontPx(10)

        SettingFontPicker {
            title: "Interface Font"
            description: "Font for labels and text. Missing fonts fall back to the defaults"
            iconName: "type"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.fontFamily
            defaultLabel: "Default (Cantarell)"
            onSelected: function(val) {
                SettingsService.setSetting("fontFamily", val);
            }
        }

        SettingDivider {}

        SettingFontPicker {
            title: "Display Font"
            description: "Font for the clock, titles and large numbers"
            iconName: "type"
            iconColor: Theme.accentPurple
            currentValue: SettingsService.fontDisplayFamily
            defaultLabel: "Same as interface font"
            onSelected: function(val) {
                SettingsService.setSetting("fontDisplayFamily", val);
            }
        }
    }

    // Clock & Time Settings
    SettingsSection {
        title: "DATE & CLOCK"

        // 1. 24-Hour Time Format
        SettingToggle {
            title: "24-Hour Time Format"
            description: "Display clock in 24-hour mode instead of 12-hour AM/PM"
            iconName: "clock"
            iconColor: Theme.accentBlue
            checked: SettingsService.use24Hour
            onToggled: function(val) {
                SettingsService.setSetting("use24Hour", val);
            }
        }

        SettingDivider {}

        // 2. Show Seconds
        SettingToggle {
            title: "Show Seconds in Expanded View"
            description: "Display live seconds counter next to the time"
            iconName: "clock"
            iconColor: Theme.accentPurple
            checked: SettingsService.showSeconds
            onToggled: function(val) {
                SettingsService.setSetting("showSeconds", val);
            }
        }
    }
}
