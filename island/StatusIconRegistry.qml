pragma Singleton
import ".."
import QtQuick
import Quickshell

// Icons in the top-right status cluster, in their default left-to-right order.
// TopRightStatusCluster lays its buttons out from this list (the buttons
// themselves are components there, keyed by id) and the "Status bar icon order"
// settings section lists it. "widgets" icons are the optional ones, drawn before
// the separator; "system" icons come after it. `settingKey` is the
// SettingsService property that turns the icon on.
Singleton {
    id: root

    readonly property var icons: [
        { "id": "nightLight", "title": "Night Light", "icon": "moon", "iconColor": Theme.accentOrange, "group": "widgets", "settingKey": "nightLightEnabled", "requires": ["kconfig-tools"] },
        { "id": "hue", "title": "Philips Hue", "icon": "bulb", "iconColor": Theme.accentOrange, "group": "widgets", "settingKey": "hueEnabled" },
        { "id": "kdeConnect", "title": "KDE Connect", "icon": "phone", "iconColor": Theme.accentGreen, "group": "widgets", "settingKey": "kdeConnectEnabled", "requires": ["kdeconnect"] },
        { "id": "gameMode", "title": "GameMode", "icon": "gamepad", "iconColor": Theme.accentGreen, "group": "widgets", "settingKey": "gameModeEnabled", "requires": ["gamemode"] },
        { "id": "caffeine", "title": "Caffeine", "icon": "coffee", "iconColor": Theme.accentOrange, "group": "system", "settingKey": "showCaffeineIcon", "requires": ["systemd-inhibit"] },
        { "id": "dnd", "title": "Do Not Disturb", "icon": "bell-off", "iconColor": Theme.accentPurple, "group": "system", "settingKey": "showDndIcon" },
        { "id": "wifi", "title": "Wi-Fi & Network", "icon": "wifi", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showWifiIcon", "requires": ["nmcli"] },
        { "id": "bluetooth", "title": "Bluetooth", "icon": "bluetooth", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showBluetoothIcon", "requires": ["bluetoothctl"] },
        { "id": "mic", "title": "Microphone", "icon": "mic", "iconColor": Theme.accentRed, "group": "system", "settingKey": "showMicIcon", "requires": ["wpctl","pactl"] },
        { "id": "clipboard", "title": "Clipboard History", "icon": "clipboard", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showClipboardIcon", "requires": ["wl-clipboard"] },
        { "id": "profile", "title": "Performance Profiles", "icon": "gauge", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showProfileIcon", "requires": ["power-profiles"] },
        { "id": "hardware", "title": "Hardware Monitor", "icon": "cpu", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showHardwareIcon" },
        { "id": "usb", "title": "USB & External Drives", "icon": "usb", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showUsbIcon", "requires": ["udisks"] },
        { "id": "notification", "title": "Notification Bell", "icon": "bell", "iconColor": Theme.accentOrange, "group": "system", "settingKey": "showNotificationIcon" },
        { "id": "battery", "title": "Power Menu and Battery", "icon": "battery", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showBatteryIcon" }
    ]

    function byId(id) {
        for (let i = 0; i < icons.length; i++) {
            if (icons[i].id === id) return icons[i];
        }
        return null;
    }
}
