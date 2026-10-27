pragma Singleton
import ".."
import QtQuick
import Quickshell

// Icons in the top-right status cluster, in their default left-to-right order.
// TopRightStatusCluster lays its buttons out from this list (the buttons
// themselves are components there, keyed by id) and the "Status bar icon order"
// Top bar settings page lists it. "widgets" icons are the optional ones, drawn
// before the separator; "system" icons come after it. `settingKey` is the
// SettingsService property that turns the icon on, and `pinKey`, for an icon that
// shows only when needed, the one that keeps it shown.
Singleton {
    id: root

    readonly property var icons: [
        { "id": "nightLight", "title": "Night Light", "description": "Switch KDE Night Light on and off and set its warmth", "icon": "moon", "iconColor": Theme.accentOrange, "group": "widgets", "settingKey": "nightLightEnabled", "requires": ["kconfig-tools"] },
        { "id": "hue", "title": "Philips Hue", "description": "Control Hue lights through a Hue Bridge. Pair with the bridge from the icon's menu", "icon": "bulb", "iconColor": Theme.accentOrange, "group": "widgets", "settingKey": "hueEnabled" },
        { "id": "kdeConnect", "title": "KDE Connect", "description": "Ping, share and send the clipboard to a phone. Pair it in the KDE Connect app first", "icon": "phone", "iconColor": Theme.accentGreen, "group": "widgets", "settingKey": "kdeConnectEnabled", "requires": ["kdeconnect"] },
        { "id": "gameMode", "title": "GameMode", "description": "Lights up while GameMode runs, and can turn it on without a game", "icon": "gamepad", "iconColor": Theme.accentGreen, "group": "widgets", "settingKey": "gameModeEnabled", "requires": ["gamemode"] },
        { "id": "caffeine", "title": "Caffeine", "description": "Keep the screen awake", "icon": "coffee", "iconColor": Theme.accentOrange, "group": "system", "settingKey": "showCaffeineIcon", "requires": ["systemd-inhibit"] },
        { "id": "dnd", "title": "Do Not Disturb", "description": "Silence notification banners. They still go to history", "icon": "bell-off", "iconColor": Theme.accentPurple, "group": "system", "settingKey": "showDndIcon" },
        { "id": "wifi", "title": "Wi-Fi & Network", "description": "Network status and Wi-Fi networks", "icon": "wifi", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showWifiIcon", "requires": ["nmcli"] },
        { "id": "bluetooth", "title": "Bluetooth", "description": "Bluetooth power and paired devices", "icon": "bluetooth", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showBluetoothIcon", "requires": ["bluetoothctl"] },
        { "id": "mic", "title": "Microphone", "description": "Microphone mute and input volume", "icon": "mic", "iconColor": Theme.accentRed, "group": "system", "settingKey": "showMicIcon", "requires": ["wpctl","pactl"] },
        { "id": "clipboard", "title": "Clipboard History", "description": "Search and copy earlier clipboard items", "icon": "clipboard", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showClipboardIcon", "requires": ["wl-clipboard"] },
        { "id": "profile", "title": "Performance Profiles", "description": "Power Saver, Balanced or Performance", "icon": "gauge", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showProfileIcon", "requires": ["power-profiles"] },
        { "id": "hardware", "title": "Hardware Monitor", "description": "CPU use and system resources", "icon": "cpu", "iconColor": Theme.accentBlue, "group": "system", "settingKey": "showHardwareIcon" },
        { "id": "usb", "title": "USB & External Drives", "description": "Connected drives and USB sticks", "icon": "usb", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showUsbIcon", "pinKey": "pinUsbIcon", "requires": ["udisks"] },
        { "id": "notification", "title": "Notification Bell", "description": "Unread notifications", "icon": "bell", "iconColor": Theme.accentOrange, "group": "system", "settingKey": "showNotificationIcon", "pinKey": "pinNotificationIcon" },
        { "id": "battery", "title": "Power Menu and Battery", "description": "Battery level and the power menu. Hiding it also hides shut down and restart", "icon": "battery", "iconColor": Theme.accentGreen, "group": "system", "settingKey": "showBatteryIcon" }
    ]

    function byId(id) {
        for (let i = 0; i < icons.length; i++) {
            if (icons[i].id === id) return icons[i];
        }
        return null;
    }
}
