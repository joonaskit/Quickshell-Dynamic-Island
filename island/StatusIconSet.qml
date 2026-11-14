import ".."
import QtQuick

// The status icon buttons, shared by the top-right status cluster and the dial
// (dialStatusIcons). Holds no visuals of its own: the host lays the buttons out with
// `delegate` over `widgetIcons` and `systemIcons`.
//
// `host` provides: openMenu (the icon id whose menu is open, or ""), toggleMenu(id),
// hoverEnabled, and unavailableTip and unavailableTipItem for the missing-tool tooltip.
Item {
    id: root

    required property var host

    visible: false

    readonly property Component delegate: statusIconDelegate

    readonly property int buttonSize: Theme.px(26)
    readonly property int iconSize: Theme.px(14)

    // Refreshes what a status icon's menu shows, as the menu opens
    function prepareMenu(id) {
        switch (id) {
        case "wifi": NetworkService.scanWifi(); break;
        case "notification": NotificationService.markAllRead(); break;
        case "profile": PowerProfileService.queryProfile(); break;
        case "usb": DeviceService.scanDevices(); break;
        case "nightLight": NightLightService.refresh(); break;
        case "gameMode": GameModeService.refresh(); break;
        case "kdeConnect": KdeConnectService.refresh(); break;
        }
    }

    // True when the user chose to hide icons whose tools are missing and this one's are
    function dropped(id) {
        return SettingsService.hideUnavailableIcons && DepsService.iconUnavailable(id);
    }

    // Hoisted service-backed visibility properties
    readonly property bool showCaffeine: SettingsService.showCaffeineIcon && !root.dropped("caffeine")
    readonly property bool showDnd: SettingsService.showDndIcon
    readonly property bool showWifi: SettingsService.showWifiIcon && !root.dropped("wifi")
    readonly property bool showBluetooth: SettingsService.showBluetoothIcon && !root.dropped("bluetooth")
    readonly property bool showMic: SettingsService.showMicIcon && !root.dropped("mic")
    readonly property bool showClipboard: SettingsService.showClipboardIcon && !root.dropped("clipboard")
    readonly property bool showProfile: SettingsService.showProfileIcon && !root.dropped("profile")
    readonly property bool showHardware: SettingsService.showHardwareIcon
    readonly property bool showUsb: SettingsService.showUsbIcon && !root.dropped("usb") && (SettingsService.pinUsbIcon || DeviceService.hasDevices || root.host.openMenu === "usb")
    readonly property bool showHue: SettingsService.hueEnabled && !root.dropped("hue")
    readonly property bool showNightLight: SettingsService.nightLightEnabled && !root.dropped("nightLight")
    readonly property bool showKdeConnect: SettingsService.kdeConnectEnabled && !root.dropped("kdeConnect")
    readonly property bool showGameMode: SettingsService.gameModeEnabled && !root.dropped("gameMode")
    readonly property int widgetCount: (showHue ? 1 : 0) + (showNightLight ? 1 : 0) + (showKdeConnect ? 1 : 0) + (showGameMode ? 1 : 0)
    readonly property bool showWidgets: widgetCount > 0
    readonly property bool showNotification: SettingsService.showNotificationIcon && (SettingsService.pinNotificationIcon || NotificationService.unreadCount > 0 || NotificationService.notifications.length > 0 || root.host.openMenu === "notification")
    readonly property bool showBattery: SettingsService.showBatteryIcon && SettingsService.showBattery

    // Count of currently visible icons
    readonly property int visibleIconCount: (showCaffeine ? 1 : 0) +
                                           (showDnd ? 1 : 0) +
                                           (showWifi ? 1 : 0) +
                                           (showBluetooth ? 1 : 0) +
                                           (showMic ? 1 : 0) +
                                           (showClipboard ? 1 : 0) +
                                           (showProfile ? 1 : 0) +
                                           (showHardware ? 1 : 0) +
                                           (showUsb ? 1 : 0) +
                                           widgetCount +
                                           (showNotification ? 1 : 0) +
                                           (showBattery ? 1 : 0)

    // Status icons come from StatusIconRegistry, in the user's order: "widgets"
    // before the separator, "system" after it. Each id maps to its button below.
    readonly property var widgetIcons: SettingsService.orderedStatusIcons.filter(i => i.group === "widgets")
    readonly property var systemIcons: SettingsService.orderedStatusIcons.filter(i => i.group === "system")

    readonly property var iconComponents: ({
        "nightLight": nightButtonComponent,
        "hue": hueButtonComponent,
        "kdeConnect": kdeButtonComponent,
        "gameMode": gameButtonComponent,
        "caffeine": coffeeButtonComponent,
        "dnd": dndButtonComponent,
        "wifi": wifiButtonComponent,
        "bluetooth": btButtonComponent,
        "mic": micButtonComponent,
        "clipboard": clipboardButtonComponent,
        "profile": profileButtonComponent,
        "hardware": hardwareButtonComponent,
        "usb": devicesButtonComponent,
        "notification": notifButtonComponent,
        "battery": batteryButtonComponent
    })

    function isIconShown(id) {
        switch (id) {
        case "nightLight": return root.showNightLight;
        case "hue": return root.showHue;
        case "kdeConnect": return root.showKdeConnect;
        case "gameMode": return root.showGameMode;
        case "caffeine": return root.showCaffeine;
        case "dnd": return root.showDnd;
        case "wifi": return root.showWifi;
        case "bluetooth": return root.showBluetooth;
        case "mic": return root.showMic;
        case "clipboard": return root.showClipboard;
        case "profile": return root.showProfile;
        case "hardware": return root.showHardware;
        case "usb": return root.showUsb;
        case "notification": return root.showNotification;
        case "battery": return root.showBattery;
        }
        return false;
    }

    // One status icon: loads the button for a registry entry. The button sets
    // its own implicit size; hidden icons take no space in the row.
    Component {
        id: statusIconDelegate

        Loader {
            id: iconLoader
            required property var modelData
            visible: root.isIconShown(modelData.id)
            // A missing tool leaves the icon dimmed and inert (or hidden, see dropped()).
            // The button is disabled, not the Loader, so hovering still shows the reason.
            readonly property bool unavailable: DepsService.iconUnavailable(modelData.id)
            sourceComponent: root.iconComponents[modelData.id]

            Binding { target: iconLoader.item; property: "enabled"; value: !iconLoader.unavailable; when: iconLoader.item !== null }
            Binding { target: iconLoader.item; property: "opacity"; value: iconLoader.unavailable ? 0.3 : 1.0; when: iconLoader.item !== null }

            HoverHandler {
                id: unavailableHover
                enabled: iconLoader.unavailable
                onHoveredChanged: {
                    if (hovered) {
                        root.host.unavailableTip = DepsService.iconProblem(iconLoader.modelData.id);
                        root.host.unavailableTipItem = iconLoader;
                    } else if (root.host.unavailableTipItem === iconLoader) {
                        root.host.unavailableTipItem = null;
                    }
                }
            }
        }
    }

    // W1. Night Light Button (only when the feature is enabled in the settings)
    Component {
        id: nightButtonComponent

        Rectangle {
            id: nightButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "nightLight") return Qt.rgba(255/255, 159/255, 10/255, 0.25);
                if (NightLightService.running) return Qt.rgba(255/255, 159/255, 10/255, 0.15);
                return "transparent";
            }
            scale: nightMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "moon"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "nightLight" || NightLightService.running) return Theme.accentOrangeStrong;
                    return nightMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: nightMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("nightLight")
            }
        }
    }

    // W2. Philips Hue Button (only when the feature is enabled in the settings)
    Component {
        id: hueButtonComponent

        Rectangle {
            id: hueButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "hue") return Qt.rgba(255/255, 159/255, 10/255, 0.25);
                if (HueService.anyOn) return Qt.rgba(255/255, 159/255, 10/255, 0.15);
                return "transparent";
            }
            scale: hueMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bulb"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "hue" || HueService.anyOn) return Theme.accentOrangeStrong;
                    return hueMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: hueMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("hue")
            }
        }
    }

    // W4. GameMode Button (only when the feature is enabled in the settings)
    Component {
        id: gameButtonComponent

        Rectangle {
            id: gameButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "gameMode") return Qt.rgba(48/255, 209/255, 88/255, 0.25);
                if (GameModeService.active) return Qt.rgba(48/255, 209/255, 88/255, 0.15);
                return "transparent";
            }
            scale: gameMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "gamepad"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "gameMode" || GameModeService.active) return Theme.accentGreenStrong;
                    return gameMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: gameMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("gameMode")
            }
        }
    }

    // W3. KDE Connect Button (only when the feature is enabled in the settings)
    Component {
        id: kdeButtonComponent

        Rectangle {
            id: kdeButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "kdeConnect") return Qt.rgba(48/255, 209/255, 88/255, 0.25);
                if (KdeConnectService.anyReachable) return Qt.rgba(48/255, 209/255, 88/255, 0.15);
                return "transparent";
            }
            scale: kdeMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "phone"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "kdeConnect" || KdeConnectService.anyReachable) return Theme.accentGreenStrong;
                    return kdeMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: kdeMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("kdeConnect")
            }
        }
    }

    // 0. Interactive Coffee Cup (Caffeine: prevents screen dimming and sleeping)
    Component {
        id: coffeeButtonComponent

        Rectangle {
            id: coffeeButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: CaffeineService.isActive ? Qt.rgba(255/255, 159/255, 10/255, 0.22) : "transparent"
            scale: coffeeMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "coffee"
                size: root.iconSize
                color: CaffeineService.isActive ? Theme.accentOrangeStrong : (coffeeMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38))
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: coffeeMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: CaffeineService.toggle()
            }
        }
    }

    // Do Not Disturb (suppresses notification banners, history is kept)
    Component {
        id: dndButtonComponent

        Rectangle {
            id: dndButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: SettingsService.dndEnabled ? Qt.rgba(191/255, 90/255, 242/255, 0.22) : "transparent"
            scale: dndMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bell-off"
                size: root.iconSize
                color: SettingsService.dndEnabled ? Theme.accentPurple : (dndMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38))
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.toggleDnd()
            }
        }
    }

    // 1. Interactive Wi-Fi Button
    Component {
        id: wifiButtonComponent

        Rectangle {
            id: wifiButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "wifi" ? Theme.accentTint(0.25) : "transparent"
            scale: wifiMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: (NetworkService.isConnected && NetworkService.isWifi) ? "wifi" : "wifi-off"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "wifi") return Theme.accent;
                    if (NetworkService.isConnected && NetworkService.isWifi) return Theme.textPrimary;
                    return wifiMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("wifi")
            }
        }
    }

    // 2. Interactive Bluetooth Button
    Component {
        id: btButtonComponent

        Rectangle {
            id: btButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "bluetooth" ? Theme.accentTint(0.25) : "transparent"
            scale: btMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bluetooth"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "bluetooth") return Theme.accent;
                    if (BluetoothService.isConnected) return Theme.accent;
                    if (BluetoothService.isEnabled) return Theme.textPrimary;
                    return btMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("bluetooth")
            }
        }
    }

    // 3. Interactive Microphone Button (triggers Microphone Mute & Volume)
    Component {
        id: micButtonComponent

        Rectangle {
            id: micButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "mic") return Qt.rgba(255/255, 69/255, 58/255, 0.25);
                if (!MicrophoneService.isMuted) return Qt.rgba(255/255, 69/255, 58/255, 0.15);
                return "transparent";
            }
            scale: micMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: MicrophoneService.isMuted ? "mic-off" : "mic"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "mic" || !MicrophoneService.isMuted) return Theme.accentRed;
                    return micMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        MicrophoneService.toggleMute();
                    } else {
                        root.host.toggleMenu("mic");
                    }
                }
            }
        }
    }

    // 4. Interactive Clipboard Button (triggers Clipboard Menu)
    Component {
        id: clipboardButtonComponent

        Rectangle {
            id: clipboardButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "clipboard" ? Theme.accentTint(0.25) : "transparent"
            scale: clipboardMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "clipboard"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "clipboard") return Theme.accent;
                    if (ClipboardService.incognito) return Theme.accentYellowStrong;
                    if (ClipboardService.currentText !== "" || ClipboardService.currentBinaryType !== "" || ClipboardService.currentFiles.length > 0) return Theme.textPrimary;
                    return clipboardMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: clipboardMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("clipboard")
            }
        }
    }

    // 5. Interactive Performance Profile Button (triggers Power Profiles Menu)
    Component {
        id: profileButtonComponent

        Rectangle {
            id: profileButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "profile" ? Qt.rgba(48/255, 209/255, 88/255, 0.25) : "transparent"
            scale: profileMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: {
                    if (PowerProfileService.activeProfile === "power-saver") return "leaf";
                    if (PowerProfileService.activeProfile === "performance") return "bolt";
                    return "gauge";
                }
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "profile") return Theme.accentGreenStrong;
                    if (PowerProfileService.activeProfile === "performance") return Theme.accentRed;
                    if (PowerProfileService.activeProfile === "power-saver") return Theme.accentGreenStrong;
                    return profileMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.45);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: profileMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("profile")
            }
        }
    }

    // 6. Interactive Hardware Resource Stats Button (triggers Mini Stats Menu)
    Component {
        id: hardwareButtonComponent

        Rectangle {
            id: hardwareButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "hardware" ? Theme.accentTint(0.25) : "transparent"
            scale: hardwareMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "cpu"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "hardware") return Theme.accent;
                    if (HardwareStatsService.cpuPercent > 50) return Theme.accentOrangeStrong;
                    return hardwareMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.45);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: hardwareMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("hardware")
            }
        }
    }

    // 7. Interactive Detachable Devices Button (triggers Detachable Devices Menu)
    Component {
        id: devicesButtonComponent

        Rectangle {
            id: devicesButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "usb") return Theme.accentTint(0.25);
                if (DeviceService.hasMountedDevices) return Qt.rgba(48/255, 209/255, 88/255, 0.2);
                if (DeviceService.hasDevices) return Theme.accentTint(0.15);
                return "transparent";
            }
            scale: devicesMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "usb"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "usb") return Theme.accent;
                    if (DeviceService.hasMountedDevices) return Theme.accentGreenStrong;
                    if (DeviceService.hasDevices) return Theme.accent;
                    return devicesMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            // Dot indicator badge when detachable devices are connected
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.px(2)
                anchors.rightMargin: Theme.px(2)
                width: Theme.px(6)
                height: Theme.px(6)
                radius: Theme.px(3)
                color: DeviceService.hasMountedDevices ? Theme.accentGreen : Theme.accent
                visible: DeviceService.hasDevices
            }

            MouseArea {
                id: devicesMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("usb")
            }
        }
    }

    // 8. Interactive Notification Bell Button (triggers Notification Menu)
    Component {
        id: notifButtonComponent

        Rectangle {
            id: notifButton
            implicitWidth: root.buttonSize
            implicitHeight: root.buttonSize
            radius: root.buttonSize / 2
            color: root.host.openMenu === "notification" ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : "transparent"
            scale: notifMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bell"
                size: root.iconSize
                color: {
                    if (root.host.openMenu === "notification") return Theme.accentOrangeStrong;
                    if (NotificationService.unreadCount > 0) return Theme.accentOrangeStrong;
                    return notifMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            // Notification unread dot indicator badge
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.px(2)
                anchors.rightMargin: Theme.px(2)
                width: Theme.px(7)
                height: Theme.px(7)
                radius: width / 2
                color: Theme.accentRed
                visible: NotificationService.unreadCount > 0
            }

            MouseArea {
                id: notifMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("notification")
            }
        }
    }

    // 9. Interactive Battery Button (triggers Power Menu)
    Component {
        id: batteryButtonComponent

        Rectangle {
            id: batteryButton
            implicitHeight: root.buttonSize
            implicitWidth: !batteryContent.isPresent ? root.buttonSize : (batteryContent.implicitWidth + Theme.px(8))
            radius: root.buttonSize / 2
            color: {
                if (root.host.openMenu === "battery") return !batteryContent.isPresent ? Qt.rgba(255/255, 214/255, 10/255, 0.22) : Qt.rgba(48/255, 209/255, 88/255, 0.2);
                return "transparent";
            }
            scale: batteryMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            BatteryIndicator {
                id: batteryContent
                anchors.centerIn: parent
                showPercentage: true
                visible: true
            }

            MouseArea {
                id: batteryMouse
                anchors.fill: parent
                hoverEnabled: root.host.hoverEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.toggleMenu("battery")
            }
        }
    }
}
