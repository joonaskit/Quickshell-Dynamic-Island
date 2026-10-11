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

    SettingsSection {
        title: "NIGHT LIGHT"
        subtitle: "Warm the screen colours in the evening"

        SettingToggle {
            title: "Night Light"
            description: "Adds a moon icon for switching KDE Night Light on and off and setting its temperature"
            iconName: "moon"
            iconColor: Theme.accentOrange
            checked: SettingsService.nightLightEnabled
            onToggled: function(val) {
                SettingsService.setSetting("nightLightEnabled", val);
            }
        }
    }

    SettingsSection {
        title: "KDE CONNECT"
        subtitle: "Ping, share and send the clipboard to a paired phone"

        SettingToggle {
            title: "KDE Connect"
            description: "Adds a phone icon for a device paired with KDE Connect. Pair the phone from the KDE Connect app first"
            iconName: "phone"
            iconColor: Theme.accentGreen
            checked: SettingsService.kdeConnectEnabled
            onToggled: function(val) {
                SettingsService.setSetting("kdeConnectEnabled", val);
            }
        }
    }
}
