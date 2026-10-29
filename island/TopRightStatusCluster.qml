import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool isTopBarMode: false
    property bool hasFullscreenApp: false
    property date currentDate: new Date()

    property bool wifiMenuOpen: false
    property bool bluetoothMenuOpen: false
    property bool powerMenuOpen: false
    property bool clipboardMenuOpen: false
    property bool notificationMenuOpen: false
    property bool micMenuOpen: false
    property bool profileMenuOpen: false
    property bool hardwareMenuOpen: false
    property bool devicesMenuOpen: false
    property bool hueMenuOpen: false
    property bool nightMenuOpen: false
    property bool kdeMenuOpen: false
    property bool gameMenuOpen: false

    readonly property bool anyMenuOpen: wifiMenuOpen || bluetoothMenuOpen || powerMenuOpen || clipboardMenuOpen || notificationMenuOpen || micMenuOpen || profileMenuOpen || hardwareMenuOpen || devicesMenuOpen || hueMenuOpen || nightMenuOpen || kdeMenuOpen || gameMenuOpen

    z: root.anyMenuOpen ? 200 : 1

    property alias hitBox: clusterBackground
    // The notch ears, for the window's blur
    property alias ears: notchEars
    property alias wifiQuickSettingsHitBox: wifiQuickSettings
    property alias bluetoothQuickSettingsHitBox: bluetoothQuickSettings
    property alias powerQuickSettingsHitBox: powerQuickSettings
    property alias clipboardQuickSettingsHitBox: clipboardQuickSettings
    property alias notificationQuickSettingsHitBox: notificationQuickSettings
    property alias micQuickSettingsHitBox: micQuickSettings
    property alias profileQuickSettingsHitBox: profileQuickSettings
    property alias hardwareQuickSettingsHitBox: hardwareQuickSettings
    property alias deviceQuickSettingsHitBox: deviceQuickSettings
    property alias hueQuickSettingsHitBox: hueQuickSettings
    property alias nightQuickSettingsHitBox: nightQuickSettings
    property alias kdeQuickSettingsHitBox: kdeQuickSettings
    property alias gameQuickSettingsHitBox: gameQuickSettings

    implicitWidth: clusterBackground.width
    implicitHeight: clusterBackground.height
    width: implicitWidth
    height: implicitHeight

    // Scaling helpers
    readonly property int buttonSize: Theme.px(26)
    readonly property int iconSize: Theme.px(14)

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
    readonly property bool showUsb: SettingsService.showUsbIcon && !root.dropped("usb") && (SettingsService.pinUsbIcon || DeviceService.hasDevices || root.devicesMenuOpen)
    readonly property bool showHue: SettingsService.hueEnabled && !root.dropped("hue")
    readonly property bool showNightLight: SettingsService.nightLightEnabled && !root.dropped("nightLight")
    readonly property bool showKdeConnect: SettingsService.kdeConnectEnabled && !root.dropped("kdeConnect")
    readonly property bool showGameMode: SettingsService.gameModeEnabled && !root.dropped("gameMode")
    readonly property int widgetCount: (showHue ? 1 : 0) + (showNightLight ? 1 : 0) + (showKdeConnect ? 1 : 0) + (showGameMode ? 1 : 0)
    readonly property bool showWidgets: widgetCount > 0
    readonly property bool showNotification: SettingsService.showNotificationIcon && (SettingsService.pinNotificationIcon || NotificationService.unreadCount > 0 || NotificationService.notifications.length > 0 || root.notificationMenuOpen)
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

    Connections {
        target: SettingsService
        function onShowWifiIconChanged() { if (!SettingsService.showWifiIcon && root.wifiMenuOpen) root.wifiMenuOpen = false; }
        function onShowBluetoothIconChanged() { if (!SettingsService.showBluetoothIcon && root.bluetoothMenuOpen) root.bluetoothMenuOpen = false; }
        function onShowMicIconChanged() { if (!SettingsService.showMicIcon && root.micMenuOpen) root.micMenuOpen = false; }
        function onShowClipboardIconChanged() { if (!SettingsService.showClipboardIcon && root.clipboardMenuOpen) root.clipboardMenuOpen = false; }
        function onShowProfileIconChanged() { if (!SettingsService.showProfileIcon && root.profileMenuOpen) root.profileMenuOpen = false; }
        function onShowHardwareIconChanged() { if (!SettingsService.showHardwareIcon && root.hardwareMenuOpen) root.hardwareMenuOpen = false; }
        function onShowUsbIconChanged() { if (!SettingsService.showUsbIcon && root.devicesMenuOpen) root.devicesMenuOpen = false; }
        function onGameModeEnabledChanged() { if (!SettingsService.gameModeEnabled && root.gameMenuOpen) root.gameMenuOpen = false; }
        function onKdeConnectEnabledChanged() { if (!SettingsService.kdeConnectEnabled && root.kdeMenuOpen) root.kdeMenuOpen = false; }
        function onNightLightEnabledChanged() { if (!SettingsService.nightLightEnabled && root.nightMenuOpen) root.nightMenuOpen = false; }
        function onHueEnabledChanged() { if (!SettingsService.hueEnabled && root.hueMenuOpen) root.hueMenuOpen = false; }
        function onShowNotificationIconChanged() { if (!SettingsService.showNotificationIcon && root.notificationMenuOpen) root.notificationMenuOpen = false; }
        function onShowBatteryIconChanged() { if (!SettingsService.showBatteryIcon && root.powerMenuOpen) root.powerMenuOpen = false; }
    }

    function closeAllMenus() {
        root.wifiMenuOpen = false;
        root.bluetoothMenuOpen = false;
        root.powerMenuOpen = false;
        root.clipboardMenuOpen = false;
        root.notificationMenuOpen = false;
        root.micMenuOpen = false;
        root.profileMenuOpen = false;
        root.hardwareMenuOpen = false;
        root.devicesMenuOpen = false;
        root.hueMenuOpen = false;
        root.nightMenuOpen = false;
        root.kdeMenuOpen = false;
        root.gameMenuOpen = false;
    }

    function toggleWifiMenu() {
        let next = !root.wifiMenuOpen;
        root.closeAllMenus();
        root.wifiMenuOpen = next;
        if (root.wifiMenuOpen) {
            NetworkService.scanWifi();
        }
    }

    function toggleBluetoothMenu() {
        let next = !root.bluetoothMenuOpen;
        root.closeAllMenus();
        root.bluetoothMenuOpen = next;
        if (root.bluetoothMenuOpen) {
            BluetoothService.queryBluetooth();
        }
    }

    function togglePowerMenu() {
        let next = !root.powerMenuOpen;
        root.closeAllMenus();
        root.powerMenuOpen = next;
    }


    function toggleClipboardMenu() {
        let next = !root.clipboardMenuOpen;
        root.closeAllMenus();
        root.clipboardMenuOpen = next;
    }

    function toggleNotificationMenu() {
        let next = !root.notificationMenuOpen;
        root.closeAllMenus();
        root.notificationMenuOpen = next;
        if (root.notificationMenuOpen) {
            NotificationService.markAllRead();
        }
    }

    function openNotificationMenu() {
        root.closeAllMenus();
        root.notificationMenuOpen = true;
        NotificationService.markAllRead();
    }

    function toggleMicMenu() {
        let next = !root.micMenuOpen;
        root.closeAllMenus();
        root.micMenuOpen = next;
        if (root.micMenuOpen) {
            MicrophoneService.queryStatus();
            MicrophoneService.querySources();
        }
    }

    function toggleProfileMenu() {
        let next = !root.profileMenuOpen;
        root.closeAllMenus();
        root.profileMenuOpen = next;
        if (root.profileMenuOpen) {
            PowerProfileService.queryProfile();
        }
    }

    function toggleHardwareMenu() {
        let next = !root.hardwareMenuOpen;
        root.closeAllMenus();
        root.hardwareMenuOpen = next;
    }

    function toggleDevicesMenu() {
        let next = !root.devicesMenuOpen;
        root.closeAllMenus();
        root.devicesMenuOpen = next;
        if (root.devicesMenuOpen) {
            DeviceService.scanDevices();
        }
    }

    function toggleHueMenu() {
        let next = !root.hueMenuOpen;
        root.closeAllMenus();
        root.hueMenuOpen = next;
    }

    function toggleNightMenu() {
        let next = !root.nightMenuOpen;
        root.closeAllMenus();
        root.nightMenuOpen = next;
        if (root.nightMenuOpen) {
            NightLightService.refresh();
        }
    }

    function toggleGameMenu() {
        let next = !root.gameMenuOpen;
        root.closeAllMenus();
        root.gameMenuOpen = next;
        if (root.gameMenuOpen) {
            GameModeService.refresh();
        }
    }

    function toggleKdeMenu() {
        let next = !root.kdeMenuOpen;
        root.closeAllMenus();
        root.kdeMenuOpen = next;
        if (root.kdeMenuOpen) {
            KdeConnectService.refresh();
        }
    }

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
                        root.unavailableTip = DepsService.iconProblem(iconLoader.modelData.id);
                        root.unavailableTipItem = iconLoader;
                    } else if (root.unavailableTipItem === iconLoader) {
                        root.unavailableTipItem = null;
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
                if (root.nightMenuOpen) return Qt.rgba(255/255, 159/255, 10/255, 0.25);
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
                    if (root.nightMenuOpen || NightLightService.running) return Theme.accentOrangeStrong;
                    return nightMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: nightMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNightMenu()
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
                if (root.hueMenuOpen) return Qt.rgba(255/255, 159/255, 10/255, 0.25);
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
                    if (root.hueMenuOpen || HueService.anyOn) return Theme.accentOrangeStrong;
                    return hueMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: hueMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleHueMenu()
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
                if (root.gameMenuOpen) return Qt.rgba(48/255, 209/255, 88/255, 0.25);
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
                    if (root.gameMenuOpen || GameModeService.active) return Theme.accentGreenStrong;
                    return gameMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: gameMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleGameMenu()
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
                if (root.kdeMenuOpen) return Qt.rgba(48/255, 209/255, 88/255, 0.25);
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
                    if (root.kdeMenuOpen || KdeConnectService.anyReachable) return Theme.accentGreenStrong;
                    return kdeMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.38);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: kdeMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleKdeMenu()
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
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
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
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
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
            color: root.wifiMenuOpen ? Theme.accentTint(0.25) : "transparent"
            scale: wifiMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: (NetworkService.isConnected && NetworkService.isWifi) ? "wifi" : "wifi-off"
                size: root.iconSize
                color: {
                    if (root.wifiMenuOpen) return Theme.accent;
                    if (NetworkService.isConnected && NetworkService.isWifi) return Theme.textPrimary;
                    return wifiMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleWifiMenu()
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
            color: root.bluetoothMenuOpen ? Theme.accentTint(0.25) : "transparent"
            scale: btMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bluetooth"
                size: root.iconSize
                color: {
                    if (root.bluetoothMenuOpen) return Theme.accent;
                    if (BluetoothService.isConnected) return Theme.accent;
                    if (BluetoothService.isEnabled) return Theme.textPrimary;
                    return btMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleBluetoothMenu()
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
                if (root.micMenuOpen) return Qt.rgba(255/255, 69/255, 58/255, 0.25);
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
                    if (root.micMenuOpen || !MicrophoneService.isMuted) return Theme.accentRed;
                    return micMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        MicrophoneService.toggleMute();
                    } else {
                        root.toggleMicMenu();
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
            color: root.clipboardMenuOpen ? Theme.accentTint(0.25) : "transparent"
            scale: clipboardMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "clipboard"
                size: root.iconSize
                color: {
                    if (root.clipboardMenuOpen) return Theme.accent;
                    if (ClipboardService.incognito) return Theme.accentYellowStrong;
                    if (ClipboardService.currentText !== "" || ClipboardService.currentBinaryType !== "" || ClipboardService.currentFiles.length > 0) return Theme.textPrimary;
                    return clipboardMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: clipboardMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleClipboardMenu()
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
            color: root.profileMenuOpen ? Qt.rgba(48/255, 209/255, 88/255, 0.25) : "transparent"
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
                    if (root.profileMenuOpen) return Theme.accentGreenStrong;
                    if (PowerProfileService.activeProfile === "performance") return Theme.accentRed;
                    if (PowerProfileService.activeProfile === "power-saver") return Theme.accentGreenStrong;
                    return profileMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.45);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: profileMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleProfileMenu()
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
            color: root.hardwareMenuOpen ? Theme.accentTint(0.25) : "transparent"
            scale: hardwareMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "cpu"
                size: root.iconSize
                color: {
                    if (root.hardwareMenuOpen) return Theme.accent;
                    if (HardwareStatsService.cpuPercent > 50) return Theme.accentOrangeStrong;
                    return hardwareMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.45);
                }
                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            }

            MouseArea {
                id: hardwareMouse
                anchors.fill: parent
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleHardwareMenu()
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
                if (root.devicesMenuOpen) return Theme.accentTint(0.25);
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
                    if (root.devicesMenuOpen) return Theme.accent;
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
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDevicesMenu()
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
            color: root.notificationMenuOpen ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : "transparent"
            scale: notifMouse.pressed ? 0.90 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

            SvgIcon {
                anchors.centerIn: parent
                name: "bell"
                size: root.iconSize
                color: {
                    if (root.notificationMenuOpen) return Theme.accentOrangeStrong;
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
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNotificationMenu()
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
                if (root.powerMenuOpen) return !batteryContent.isPresent ? Qt.rgba(255/255, 214/255, 10/255, 0.22) : Qt.rgba(48/255, 209/255, 88/255, 0.2);
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
                hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePowerMenu()
            }
        }
    }
    // Hover state matching IslandPill: expands capsule smoothly on pill hover (disabled in full screen / top-bar mode)
    readonly property bool isClusterHovered: clusterHoverHandler.hovered && !root.anyMenuOpen && !root.isTopBarMode && !root.hasFullscreenApp

    // Target dimensions for liquid jelly morphing
    readonly property real compactWidth: {
        if (!root.isTopBarMode && root.visibleIconCount === 0) return 0;
        return contentRow.implicitWidth + (root.isTopBarMode ? Theme.px(14) : Theme.px(26)) + (root.isClusterHovered ? Theme.px(8) : 0);
    }
    readonly property real expandedWidth: Math.max(Theme.px(350), compactWidth)
    readonly property real targetWidth: root.anyMenuOpen ? expandedWidth : compactWidth

    readonly property real compactHeight: root.isTopBarMode ? (Theme.topBarHeight + 1) : Theme.compactHeight

    readonly property real activeMenuHeight: {
        if (root.wifiMenuOpen) return wifiQuickSettings.implicitHeight;
        if (root.bluetoothMenuOpen) return bluetoothQuickSettings.implicitHeight;
        if (root.powerMenuOpen) return powerQuickSettings.implicitHeight;
        if (root.clipboardMenuOpen) return clipboardQuickSettings.implicitHeight;
        if (root.notificationMenuOpen) return notificationQuickSettings.implicitHeight;
        if (root.micMenuOpen) return micQuickSettings.implicitHeight;
        if (root.profileMenuOpen) return profileQuickSettings.implicitHeight;
        if (root.hardwareMenuOpen) return hardwareQuickSettings.implicitHeight;
        if (root.devicesMenuOpen) return deviceQuickSettings.implicitHeight;
        if (root.hueMenuOpen) return hueQuickSettings.implicitHeight;
        if (root.nightMenuOpen) return nightQuickSettings.implicitHeight;
        if (root.kdeMenuOpen) return kdeQuickSettings.implicitHeight;
        if (root.gameMenuOpen) return gameQuickSettings.implicitHeight;
        return 0;
    }

    readonly property real targetHeight: {
        if (!root.anyMenuOpen) return compactHeight;
        if (root.isTopBarMode) return compactHeight + 1 + root.activeMenuHeight + Theme.px(20) + (hang.bubbleOpen ? hang.bubbleGap : 0);
        return Theme.compactHeight + root.activeMenuHeight + Theme.px(20);
    }

    readonly property real targetTopRadius: {
        if (root.isTopBarMode || Theme.notchStyle) return 0;
        return root.anyMenuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    readonly property real targetBottomRadius: {
        if (root.isTopBarMode) return root.anyMenuOpen ? Theme.px(18) : 0;
        if (Theme.notchStyle && !root.anyMenuOpen) return Theme.notchRadius;
        return root.anyMenuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    // Ambient drop shadow, morphing smoothly with the capsule
    Rectangle {
        id: shadow
        anchors.centerIn: clusterBackground
        width: clusterBackground.width + Theme.px(12)
        height: clusterBackground.height + Theme.px(10)

        topLeftRadius: root.targetTopRadius + Theme.px(4)
        topRightRadius: root.targetTopRadius + Theme.px(4)
        bottomLeftRadius: root.targetBottomRadius + Theme.px(4)
        bottomRightRadius: root.targetBottomRadius + Theme.px(4)

        color: Theme.islandShadow
        opacity: (root.isTopBarMode && !root.anyMenuOpen && clusterBackground.height <= root.compactHeight + 1) ? 0.0 : (root.anyMenuOpen ? 0.65 : (root.targetWidth > 0 ? 0.45 : 0.0))
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Names the missing tool when hovering a dimmed icon. It lives here, not in
    // the icon, because the cluster background clips its children.
    property string unavailableTip: ""
    property Item unavailableTipItem: null

    Rectangle {
        id: unavailableTooltip
        readonly property point anchorPoint: root.unavailableTipItem
            ? root.unavailableTipItem.mapToItem(root, root.unavailableTipItem.width / 2, root.unavailableTipItem.height)
            : Qt.point(0, 0)
        visible: opacity > 0.01
        opacity: root.unavailableTipItem && root.unavailableTip !== "" ? 1.0 : 0.0
        z: 100
        width: tipText.implicitWidth + Theme.px(16)
        height: tipText.implicitHeight + Theme.px(10)
        x: Math.max(0, Math.min(root.width - width, anchorPoint.x - width / 2))
        y: anchorPoint.y + Theme.px(6)
        radius: Theme.cornerPx(8)
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.overlay(0.12)

        Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.unavailableTip
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(11)
            color: Theme.textPrimary
        }
    }

    // Open in top-bar mode, the cluster grows out of the bar (BarHang)
    BarHang {
        id: hang
        body: clusterBackground
        pill: root
        topBarMode: root.isTopBarMode
        open: root.anyMenuOpen
        barEdge: root.barEdge
    }
    // How tall the bar's lower edge is (TopBarWings.edgeDepth)
    property real barEdge: 0
    // Where the body is cut into the bar, for TopBarWings.gaps
    readonly property var barGap: hang.gap
    // The ears' blur would be square, which below the bar shows as a clear patch beside
    // the body, so hanging from the bar they go without
    readonly property var earsBlur: hang.joined ? null : notchEars
    // The window's blur: the card while detached, else the body
    readonly property Item blurBody: hang.bubble ? bubbleCard : clusterBackground

    NotchEars {
        id: notchEars
        body: clusterBackground
        active: (Theme.notchEars && !root.isTopBarMode) || hang.joined
        inset: hang.joined ? hang.barDepth : 0
        color: hang.joined ? hang.barFill : clusterBackground.color
        // Hanging from the bar, no outline: it reads as part of the bar
        outlined: Theme.glass && !hang.joined
    }

    // Morphed Cluster Background capsule: Exactly matches the Island physics and styling
    Rectangle {
        id: clusterBackground
        anchors.top: parent.top
        // Hanging from the bar, clear over it, so the bar shows through as one strip
        gradient: hang.fill
        anchors.right: parent.right
        width: root.targetWidth
        height: root.targetHeight
        clip: true
        visible: root.isTopBarMode || root.visibleIconCount > 0 || root.anyMenuOpen

        HoverHandler {
            id: clusterHoverHandler
            enabled: !root.isTopBarMode && !root.hasFullscreenApp
        }

        topLeftRadius: root.targetTopRadius
        topRightRadius: root.targetTopRadius
        bottomLeftRadius: root.targetBottomRadius
        bottomRightRadius: root.targetBottomRadius

        // Solid, or frosted like the side pills while compact (frostedStatusIcons); a menu is always solid, for reading
        readonly property bool frosted: SettingsService.frostedStatusIcons && !root.anyMenuOpen
        color: (root.isTopBarMode && !root.anyMenuOpen && clusterBackground.height <= root.compactHeight + 1) ? "transparent" : (frosted ? Theme.pillFrosted : (root.anyMenuOpen ? Theme.menuSurface : Theme.islandSurface))
        // On glass with notch ears, GlassSurface draws the hairline instead
        border.width: (root.isTopBarMode || (Theme.glass && notchEars.active)) ? 0 : 1
        border.color: frosted ? Theme.pillFrostedBorder : Theme.islandBorder

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Theme.animEasing
                easing.overshoot: Theme.animOvershoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.isTopBarMode ? Theme.animDurationTopBar : Theme.animDuration
                easing.type: root.anyMenuOpen ? Theme.animEasing : Easing.OutCubic
                easing.overshoot: root.anyMenuOpen ? Theme.animOvershoot : 1.0
            }
        }
        Behavior on topLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on topRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomLeftRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on bottomRightRadius {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        // Detached on glass: the menu's card below the bar (BarHang.bubble)
        BarBubble {
            id: bubbleCard
            hang: hang
        }

        GlassSurface {
            body: clusterBackground
            flushTop: notchEars.active
            flatTop: Theme.notchStyle && !root.isTopBarMode
            flushInset: notchEars.inset
            hairline: !hang.joined
            active: Theme.glass && !hang.bubble
        }

        // Top Header Bar containing the notification & status buttons
        Item {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTopBarMode ? (Theme.topBarHeight + 1) : Theme.compactHeight

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.px(6)

                // Calendar / Date Readout (only in top-bar mode)
                RowLayout {
                    spacing: Theme.px(5)
                    visible: root.isTopBarMode

                    SvgIcon {
                        name: "calendar"
                        size: Theme.px(12)
                        color: Theme.textSecondary
                    }

                    Text {
                        text: Qt.formatDateTime(root.currentDate, "ddd d MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                // Divider between date and status icons when in top bar mode
                Rectangle {
                    Layout.preferredWidth: visible ? 1 : 0
                    Layout.preferredHeight: Theme.px(14)
                    color: Theme.overlay(0.15)
                    visible: root.isTopBarMode && (root.visibleIconCount > 0)
                    Layout.rightMargin: Theme.px(4)
                }

                // Optional widget icons, in the user's order
                Repeater {
                    model: root.widgetIcons
                    delegate: statusIconDelegate
                }

                // Separates the optional widget icons from the system icons
                Rectangle {
                    Layout.preferredWidth: visible ? Math.max(1, Theme.px(1)) : 0
                    Layout.preferredHeight: Theme.px(16)
                    radius: width / 2
                    color: Theme.overlay(0.4)
                    visible: root.showWidgets && root.visibleIconCount > root.widgetCount
                    Layout.leftMargin: Theme.px(2)
                    Layout.rightMargin: Theme.px(2)
                }

                // System icons, in the user's order
                Repeater {
                    model: root.systemIcons
                    delegate: statusIconDelegate
                }
            }
        }

        // Hairline Divider below buttons when morphed open
        Rectangle {
            id: divider
            anchors.top: headerArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.overlay(0.08)
            // Detached, the card's edge parts the menu from the bar instead
            opacity: root.anyMenuOpen && !hang.bubble ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }
        }

        // Embedded Morphed Menu Container
        Item {
            id: menuContainer
            anchors.top: divider.bottom
            // Detached, below the gap to the card's top
            anchors.topMargin: (hang.bubble ? hang.bubbleGap : 0) + menuGap
            readonly property real menuGap: 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: grabberArea.top
            clip: true
            opacity: root.anyMenuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }

            // 1. Wi-Fi Quick Settings
            WifiQuickSettings {
                id: wifiQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.wifiMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.wifiMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 2. Bluetooth Quick Settings
            BluetoothQuickSettings {
                id: bluetoothQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.bluetoothMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.bluetoothMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 3. Power & Battery Quick Settings
            PowerQuickSettings {
                id: powerQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.powerMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.powerMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 4. Clipboard Quick Settings
            ClipboardQuickSettings {
                id: clipboardQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.clipboardMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.clipboardMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 5. Notification History List
            Item {
                id: notificationWrapper
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                implicitHeight: notificationQuickSettings.implicitHeight
                opacity: root.notificationMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

                NotificationListView {
                    id: notificationQuickSettings
                    anchors.left: parent.left
                    anchors.right: parent.right
                }
            }

            // 6. Microphone Quick Settings
            MicrophoneQuickSettings {
                id: micQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.micMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.micMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 7. Performance Profiles Quick Settings
            PowerProfileQuickSettings {
                id: profileQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.profileMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.profileMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 8. Hardware Stats Quick Settings
            HardwareStatsQuickSettings {
                id: hardwareQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.hardwareMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.hardwareMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 9. Detachable Devices Quick Settings
            DeviceQuickSettings {
                id: deviceQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.devicesMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.devicesMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 10. Philips Hue Quick Settings
            HueQuickSettings {
                id: hueQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.hueMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.hueMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 13. GameMode Quick Settings
            GameModeQuickSettings {
                id: gameQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.gameMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.gameMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 12. KDE Connect Quick Settings
            KdeConnectQuickSettings {
                id: kdeQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.kdeMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.kdeMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }

            // 11. Night Light Quick Settings
            NightLightQuickSettings {
                id: nightQuickSettings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                embedded: true
                opacity: root.nightMenuOpen ? 1.0 : 0.0
                visible: opacity > 0.01
                onRequestClose: root.nightMenuOpen = false
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            }
        }

        // Bottom Grabber handle when morphed open
        Item {
            id: grabberArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 16
            opacity: root.anyMenuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 4
                radius: 2
                color: Theme.overlay(0.25)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeAllMenus()
            }

            // Opens the settings at the status icons, or the optional icons for theirs
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.px(4)
                width: Theme.px(22)
                height: Theme.px(16)
                radius: height / 2
                color: iconSettingsMouse.containsMouse ? Theme.overlay(0.12) : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                SvgIcon {
                    anchors.centerIn: parent
                    name: "settings"
                    size: Theme.px(11)
                    color: iconSettingsMouse.containsMouse ? Theme.textPrimary : Theme.overlay(0.35)
                }

                MouseArea {
                    id: iconSettingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let optional = root.hueMenuOpen || root.nightMenuOpen || root.kdeMenuOpen || root.gameMenuOpen;
                        root.closeAllMenus();
                        SettingsService.requestOpenSettings("Top bar", optional ? "optionalIcons" : "statusIcons");
                    }
                }
            }
        }
    }
}
