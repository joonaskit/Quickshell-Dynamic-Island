import "../.."
import QtQuick

SettingsCategory {

    // Optional widgets that are off until enabled
    SettingsSection {
        title: "PHILIPS HUE"
        subtitle: "Control Hue lights from the status bar"

        SettingToggle {
            title: "Philips Hue"
            description: "Adds a lamp icon for controlling Hue lights through a Hue Bridge on your network. Pair with the bridge from the icon's popup"
            iconName: "bulb"
            iconColor: Theme.accentOrange
            checked: SettingsService.hueEnabled
            onToggled: function(val) {
                SettingsService.setSetting("hueEnabled", val);
            }
        }
    }
}
