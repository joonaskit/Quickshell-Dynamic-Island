import "../.."
import QtQuick

SettingsCategory {

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
