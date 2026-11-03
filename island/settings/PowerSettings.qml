import "../.."
import QtQuick

SettingsCategory {

    SettingsSection {
        key: "battery"
        title: "BATTERY"

        SettingToggle {
            title: "60 Hz on Battery"
            description: "Lowers the built-in screen's refresh rate while unplugged and restores it when plugged in"
            warning: PowerProfileService.lowRefreshProblem
            keywords: "refresh rate hertz battery saver unplugged display"
            iconName: "desktop"
            iconColor: Theme.accentGreenStrong
            enabled: PowerProfileService.lowRefreshAvailable
            // Unavailable shows as off, leaving the saved setting for when kscreen-doctor is installed
            checked: SettingsService.lowRefreshOnBattery && PowerProfileService.lowRefreshAvailable
            onToggled: SettingsService.toggleSetting("lowRefreshOnBattery")
        }
    }
}
