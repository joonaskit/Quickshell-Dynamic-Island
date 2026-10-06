import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Window & Workspace Pills (Top Left)
    SettingsSection {
        title: "WINDOW & WORKSPACE PILLS"
        subtitle: "Top Left Corner"

        // 1. Window Controls Main Toggle
        SettingToggle {
            title: "Window Controls Pill"
            description: "Display active application name, window title, and window actions menu"
            iconName: "window"
            iconColor: Theme.accentBlue
            checked: SettingsService.showWindowControls
            onToggled: function(val) {
                SettingsService.setSetting("showWindowControls", val);
            }
        }

        SettingDivider {}

        // 1b. Auto-Hide Window Controls Sub-Toggle
        SettingToggle {
            title: "Auto-Hide Window Controls"
            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
            iconName: "chevron-up"
            iconColor: Theme.accentBlue
            isSubOption: true
            enabled: SettingsService.showWindowControls
            checked: SettingsService.autoHideWindowControls
            onToggled: function(val) {
                SettingsService.setSetting("autoHideWindowControls", val);
            }
        }

        SettingDivider {}

        // 2. Virtual Desktops Main Toggle
        SettingToggle {
            title: "Virtual Desktops Pill"
            description: "Display workspace switcher dots, desktop numbers, and quick workspace actions"
            iconName: "desktop"
            iconColor: Theme.accentPurple
            checked: SettingsService.showVirtualDesktops
            onToggled: function(val) {
                SettingsService.setSetting("showVirtualDesktops", val);
            }
        }

        SettingDivider {}

        // 2b. Auto-Hide Virtual Desktops Sub-Toggle
        SettingToggle {
            title: "Auto-Hide Virtual Desktops"
            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
            iconName: "chevron-up"
            iconColor: Theme.accentPurple
            isSubOption: true
            enabled: SettingsService.showVirtualDesktops
            checked: SettingsService.autoHideVirtualDesktops
            onToggled: function(val) {
                SettingsService.setSetting("autoHideVirtualDesktops", val);
            }
        }
    }

    // Top Right Status Bar Icons
    SettingsSection {
        title: "STATUS BAR ICONS"
        subtitle: "Top Right Cluster"

        // 1. Caffeine
        SettingToggle {
            title: "Caffeine"
            description: "Keep awake icon to prevent screen sleep and dimming"
            iconName: "coffee"
            iconColor: Theme.accentOrange
            checked: SettingsService.showCaffeineIcon
            onToggled: function(val) {
                SettingsService.setSetting("showCaffeineIcon", val);
            }
        }

        SettingDivider {}

        // 2. Wi-Fi
        SettingToggle {
            title: "Wi-Fi & Network"
            description: "Network connectivity status & quick Wi-Fi selection menu"
            iconName: "wifi"
            iconColor: Theme.accentBlue
            checked: SettingsService.showWifiIcon
            onToggled: function(val) {
                SettingsService.setSetting("showWifiIcon", val);
            }
        }

        SettingDivider {}

        // 3. Bluetooth
        SettingToggle {
            title: "Bluetooth"
            description: "Bluetooth power state and quick paired devices list"
            iconName: "bluetooth"
            iconColor: Theme.accentBlue
            checked: SettingsService.showBluetoothIcon
            onToggled: function(val) {
                SettingsService.setSetting("showBluetoothIcon", val);
            }
        }

        SettingDivider {}

        // 4. Microphone
        SettingToggle {
            title: "Microphone"
            description: "Input mute toggle & microphone volume control"
            iconName: "mic"
            iconColor: Theme.accentRed
            checked: SettingsService.showMicIcon
            onToggled: function(val) {
                SettingsService.setSetting("showMicIcon", val);
            }
        }

        SettingDivider {}

        // 5. Clipboard History
        SettingToggle {
            title: "Clipboard History"
            description: "Quick clipboard search and copy history manager"
            iconName: "clipboard"
            iconColor: Theme.accentBlue
            checked: SettingsService.showClipboardIcon
            onToggled: function(val) {
                SettingsService.setSetting("showClipboardIcon", val);
            }
        }

        SettingDivider {}

        // 6. Performance Profiles
        SettingToggle {
            title: "Performance Profiles"
            description: "Switch power profile between Power Saver, Balanced, and Performance"
            iconName: "gauge"
            iconColor: Theme.accentGreen
            checked: SettingsService.showProfileIcon
            onToggled: function(val) {
                SettingsService.setSetting("showProfileIcon", val);
            }
        }

        SettingDivider {}

        // 7. Hardware Monitor
        SettingToggle {
            title: "Hardware Monitor"
            description: "Live CPU percentage & system resource statistics"
            iconName: "cpu"
            iconColor: Theme.accentBlue
            checked: SettingsService.showHardwareIcon
            onToggled: function(val) {
                SettingsService.setSetting("showHardwareIcon", val);
            }
        }

        SettingDivider {}

        // 8. Battery Indicator
        SettingToggle {
            title: "Battery Indicator"
            description: "Display battery percentage widget & power menu"
            iconName: "battery"
            iconColor: Theme.accentGreen
            checked: SettingsService.showBatteryIcon
            onToggled: function(val) {
                SettingsService.setSetting("showBatteryIcon", val);
            }
        }
    }

    // Dynamic Icons & Pinning
    SettingsSection {
        title: "DYNAMIC ICONS & PINNING"
        subtitle: "Auto-show or keep pinned"

        // 1. USB Devices Main Toggle
        SettingToggle {
            title: "USB & External Drives"
            description: "Automatically shows when external drives or USB sticks are connected"
            iconName: "usb"
            iconColor: Theme.accentGreen
            checked: SettingsService.showUsbIcon
            onToggled: function(val) {
                SettingsService.setSetting("showUsbIcon", val);
            }
        }

        SettingDivider {}

        // 1b. Pin USB Toggle
        SettingToggle {
            title: "Always Show USB Icon (Pin)"
            description: "Keep USB icon permanently visible even when no drives are plugged in"
            iconName: "pin"
            iconColor: Theme.accentGreen
            isSubOption: true
            enabled: SettingsService.showUsbIcon
            checked: SettingsService.pinUsbIcon
            onToggled: function(val) {
                SettingsService.setSetting("pinUsbIcon", val);
            }
        }

        SettingDivider {}

        // 2. Notifications Main Toggle
        SettingToggle {
            title: "Notification Bell"
            description: "Automatically shows when unread or active notifications exist"
            iconName: "bell"
            iconColor: Theme.accentOrange
            checked: SettingsService.showNotificationIcon
            onToggled: function(val) {
                SettingsService.setSetting("showNotificationIcon", val);
            }
        }

        SettingDivider {}

        // 2b. Pin Notification Toggle
        SettingToggle {
            title: "Always Show Notification Bell (Pin)"
            description: "Keep bell permanently visible even when there are no unread notifications"
            iconName: "pin"
            iconColor: Theme.accentOrange
            isSubOption: true
            enabled: SettingsService.showNotificationIcon
            checked: SettingsService.pinNotificationIcon
            onToggled: function(val) {
                SettingsService.setSetting("pinNotificationIcon", val);
            }
        }

        SettingDivider {}

        // 3. Background Apps Tray Pill Main Toggle
        SettingToggle {
            title: "Background Apps Tray Pill"
            description: "Display persistent background application indicators and tray icons capsule"
            iconName: "desktop"
            iconColor: Theme.accentIndigo
            checked: SettingsService.showAppTrayPill
            onToggled: function(val) {
                SettingsService.setSetting("showAppTrayPill", val);
            }
        }

        SettingDivider {}

        // 3b. Auto-Hide Tray Pill Sub-Toggle
        SettingToggle {
            title: "Auto-Hide Tray Pill"
            description: "Glides upwards off-screen and reveals when holding mouse at top edge for a moment"
            iconName: "chevron-up"
            iconColor: Theme.accentIndigo
            isSubOption: true
            enabled: SettingsService.showAppTrayPill
            checked: SettingsService.autoHideAppTrayPill
            onToggled: function(val) {
                SettingsService.setSetting("autoHideAppTrayPill", val);
            }
        }

        SettingDivider {}

        // 4. Detached Notification Bubble Toggle
        SettingToggle {
            title: "Detached Notification Bubble"
            description: "Secondary floating island circle displaying unread notification alerts"
            iconName: "bell"
            iconColor: Theme.accentOrange
            checked: SettingsService.showDetachedNotifBubble
            onToggled: function(val) {
                SettingsService.setSetting("showDetachedNotifBubble", val);
            }
        }
    }
}
