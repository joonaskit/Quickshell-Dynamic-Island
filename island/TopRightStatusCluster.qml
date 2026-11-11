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

    // The icon buttons (StatusIconSet), shared with the dial
    StatusIconSet {
        id: iconSet
        host: root
    }

    // StatusIconSet's host interface
    readonly property bool hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
    readonly property string openMenu: {
        if (root.wifiMenuOpen) return "wifi";
        if (root.bluetoothMenuOpen) return "bluetooth";
        if (root.powerMenuOpen) return "battery";
        if (root.clipboardMenuOpen) return "clipboard";
        if (root.notificationMenuOpen) return "notification";
        if (root.micMenuOpen) return "mic";
        if (root.profileMenuOpen) return "profile";
        if (root.hardwareMenuOpen) return "hardware";
        if (root.devicesMenuOpen) return "usb";
        if (root.hueMenuOpen) return "hue";
        if (root.nightMenuOpen) return "nightLight";
        if (root.kdeMenuOpen) return "kdeConnect";
        if (root.gameMenuOpen) return "gameMode";
        return "";
    }

    // Opens or closes the menu of a status icon, by its StatusIconRegistry id
    function toggleMenu(id) {
        switch (id) {
        case "wifi": root.toggleWifiMenu(); break;
        case "bluetooth": root.toggleBluetoothMenu(); break;
        case "battery": root.togglePowerMenu(); break;
        case "clipboard": root.toggleClipboardMenu(); break;
        case "notification": root.toggleNotificationMenu(); break;
        case "mic": root.toggleMicMenu(); break;
        case "profile": root.toggleProfileMenu(); break;
        case "hardware": root.toggleHardwareMenu(); break;
        case "usb": root.toggleDevicesMenu(); break;
        case "hue": root.toggleHueMenu(); break;
        case "nightLight": root.toggleNightMenu(); break;
        case "kdeConnect": root.toggleKdeMenu(); break;
        case "gameMode": root.toggleGameMenu(); break;
        }
    }

    // With the icons in the dial (dialStatusIcons), the corner shows them only while a
    // menu opened from there is open
    readonly property bool iconsAway: SettingsService.dialStatusIcons && SettingsService.launcherStyle === "dial" && !root.anyMenuOpen
    readonly property int visibleIconCount: root.iconsAway ? 0 : iconSet.visibleIconCount

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
        if (root.wifiMenuOpen) iconSet.prepareMenu("wifi");
    }

    function toggleBluetoothMenu() {
        let next = !root.bluetoothMenuOpen;
        root.closeAllMenus();
        root.bluetoothMenuOpen = next;
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
        if (root.notificationMenuOpen) iconSet.prepareMenu("notification");
    }

    function openNotificationMenu() {
        root.closeAllMenus();
        root.notificationMenuOpen = true;
        iconSet.prepareMenu("notification");
    }

    function toggleMicMenu() {
        let next = !root.micMenuOpen;
        root.closeAllMenus();
        root.micMenuOpen = next;
    }

    function toggleProfileMenu() {
        let next = !root.profileMenuOpen;
        root.closeAllMenus();
        root.profileMenuOpen = next;
        if (root.profileMenuOpen) iconSet.prepareMenu("profile");
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
        if (root.devicesMenuOpen) iconSet.prepareMenu("usb");
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
        if (root.nightMenuOpen) iconSet.prepareMenu("nightLight");
    }

    function toggleGameMenu() {
        let next = !root.gameMenuOpen;
        root.closeAllMenus();
        root.gameMenuOpen = next;
        if (root.gameMenuOpen) iconSet.prepareMenu("gameMode");
    }

    function toggleKdeMenu() {
        let next = !root.kdeMenuOpen;
        root.closeAllMenus();
        root.kdeMenuOpen = next;
        if (root.kdeMenuOpen) iconSet.prepareMenu("kdeConnect");
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
        // Not with an empty body (the icons are in the dial): the two ears would meet as a
        // black triangle in the corner
        active: ((Theme.notchEars && !root.isTopBarMode) || hang.joined) && clusterBackground.visible
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
                    model: root.iconsAway ? [] : iconSet.widgetIcons
                    delegate: iconSet.delegate
                }

                // Separates the optional widget icons from the system icons
                Rectangle {
                    Layout.preferredWidth: visible ? Math.max(1, Theme.px(1)) : 0
                    Layout.preferredHeight: Theme.px(16)
                    radius: width / 2
                    color: Theme.overlay(0.4)
                    visible: iconSet.showWidgets && root.visibleIconCount > iconSet.widgetCount
                    Layout.leftMargin: Theme.px(2)
                    Layout.rightMargin: Theme.px(2)
                }

                // System icons, in the user's order
                Repeater {
                    model: root.iconsAway ? [] : iconSet.systemIcons
                    delegate: iconSet.delegate
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
