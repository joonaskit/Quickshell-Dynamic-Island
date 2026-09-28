import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

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

    readonly property bool anyMenuOpen: wifiMenuOpen || bluetoothMenuOpen || powerMenuOpen || clipboardMenuOpen || notificationMenuOpen || micMenuOpen || profileMenuOpen || hardwareMenuOpen

    z: root.anyMenuOpen ? 200 : 1

    property alias hitBox: clusterBackground
    property alias wifiQuickSettingsHitBox: wifiQuickSettings
    property alias bluetoothQuickSettingsHitBox: bluetoothQuickSettings
    property alias powerQuickSettingsHitBox: powerQuickSettings
    property alias clipboardQuickSettingsHitBox: clipboardQuickSettings
    property alias notificationQuickSettingsHitBox: notificationQuickSettings
    property alias micQuickSettingsHitBox: micQuickSettings
    property alias profileQuickSettingsHitBox: profileQuickSettings
    property alias hardwareQuickSettingsHitBox: hardwareQuickSettings

    implicitWidth: clusterBackground.width
    implicitHeight: clusterBackground.height

    function closeAllMenus() {
        root.wifiMenuOpen = false;
        root.bluetoothMenuOpen = false;
        root.powerMenuOpen = false;
        root.clipboardMenuOpen = false;
        root.notificationMenuOpen = false;
        root.micMenuOpen = false;
        root.profileMenuOpen = false;
        root.hardwareMenuOpen = false;
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
        if (root.clipboardMenuOpen) {
            ClipboardService.queryClipboard();
        }
    }

    function toggleNotificationMenu() {
        let next = !root.notificationMenuOpen;
        root.closeAllMenus();
        root.notificationMenuOpen = next;
        if (root.notificationMenuOpen) {
            NotificationService.markAllRead();
        }
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

    // Hover state matching IslandPill: expands capsule smoothly on pill hover (disabled in full screen / top-bar mode)
    readonly property bool isClusterHovered: clusterHoverHandler.hovered && !root.anyMenuOpen && !root.isTopBarMode && !root.hasFullscreenApp

    // Target dimensions for liquid jelly morphing
    readonly property real compactWidth: contentRow.implicitWidth + (root.isTopBarMode ? 14 : 26) + (root.isClusterHovered ? 8 : 0)
    readonly property real expandedWidth: Math.max(350, compactWidth)
    readonly property real targetWidth: (root.anyMenuOpen && !root.isTopBarMode) ? expandedWidth : compactWidth

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
        return 0;
    }

    readonly property real targetHeight: {
        if (!root.anyMenuOpen) return compactHeight;
        if (root.isTopBarMode) return compactHeight + 1 + root.activeMenuHeight + 20;
        return 42 + root.activeMenuHeight + 20;
    }

    readonly property real targetTopRadius: {
        if (root.isTopBarMode) return 0;
        return root.anyMenuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    readonly property real targetBottomRadius: {
        if (root.isTopBarMode) return root.anyMenuOpen ? 18 : 0;
        return root.anyMenuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    // Ambient drop shadow, morphing smoothly with the capsule
    Rectangle {
        id: shadow
        anchors.centerIn: clusterBackground
        width: clusterBackground.width + 12
        height: clusterBackground.height + 10

        topLeftRadius: root.targetTopRadius + 4
        topRightRadius: root.targetTopRadius + 4
        bottomLeftRadius: root.targetBottomRadius + 4
        bottomRightRadius: root.targetBottomRadius + 4

        color: Theme.islandShadow
        opacity: (root.isTopBarMode && !root.anyMenuOpen) ? 0.0 : (root.anyMenuOpen ? 0.65 : 0.45)
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Morphed Cluster Background capsule: Exactly matches the Dynamic Island physics and styling
    Rectangle {
        id: clusterBackground
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.targetWidth
        height: root.targetHeight
        clip: true

        HoverHandler {
            id: clusterHoverHandler
            enabled: !root.isTopBarMode && !root.hasFullscreenApp
        }

        topLeftRadius: root.targetTopRadius
        topRightRadius: root.targetTopRadius
        bottomLeftRadius: root.targetBottomRadius
        bottomRightRadius: root.targetBottomRadius

        color: (root.isTopBarMode && !root.anyMenuOpen) ? "transparent" : Theme.islandBackground
        border.width: root.isTopBarMode ? 0 : 1
        border.color: Theme.islandBorder

        Behavior on width {
            enabled: !root.isTopBarMode
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Theme.animEasing
                easing.overshoot: Theme.animOvershoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.isTopBarMode ? 260 : Theme.animDuration
                easing.type: (!root.isTopBarMode && root.anyMenuOpen) ? Theme.animEasing : Easing.OutCubic
                easing.overshoot: (!root.isTopBarMode && root.anyMenuOpen) ? Theme.animOvershoot : 1.0
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

        // Top Header Bar containing the notification & status buttons
        Item {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isTopBarMode ? (Theme.topBarHeight + 1) : 40

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 6

                // Calendar / Date Readout (only in top-bar mode)
                RowLayout {
                    spacing: 5
                    visible: root.isTopBarMode

                    SvgIcon {
                        name: "calendar"
                        size: 12
                        color: Theme.textSecondary
                    }

                    Text {
                        text: Qt.formatDateTime(root.currentDate, "ddd d MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                // Divider between date and status icons when in top bar mode
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: Qt.rgba(1, 1, 1, 0.15)
                    visible: root.isTopBarMode
                    Layout.rightMargin: 4
                }

                // 0. Interactive Coffee Cup (Caffeine: prevents screen dimming and sleeping)
                Rectangle {
                    id: coffeeButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: CaffeineService.isActive ? Qt.rgba(255/255, 159/255, 10/255, 0.22) : "transparent"
                    scale: coffeeMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "coffee"
                        size: 14
                        color: CaffeineService.isActive ? Theme.accentOrange : (coffeeMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.38))
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: coffeeMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: CaffeineService.toggle()
                    }
                }

                // 1. Interactive Wi-Fi Button
                Rectangle {
                    id: wifiButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.wifiMenuOpen ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : "transparent"
                    scale: wifiMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: (NetworkService.isConnected && NetworkService.isWifi) ? "wifi" : "wifi-off"
                        size: 14
                        color: {
                            if (root.wifiMenuOpen) return Theme.accentBlue;
                            if (NetworkService.isConnected && NetworkService.isWifi) return Theme.textPrimary;
                            return wifiMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.35);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: wifiMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWifiMenu()
                    }
                }

                // 2. Interactive Bluetooth Button
                Rectangle {
                    id: btButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.bluetoothMenuOpen ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : "transparent"
                    scale: btMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "bluetooth"
                        size: 14
                        color: {
                            if (root.bluetoothMenuOpen) return Theme.accentBlue;
                            if (BluetoothService.isConnected) return Theme.accentBlue;
                            if (BluetoothService.isEnabled) return Theme.textPrimary;
                            return btMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.35);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: btMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleBluetoothMenu()
                    }
                }

                // 3. Interactive Microphone Button (triggers Microphone Mute & Volume)
                Rectangle {
                    id: micButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: {
                        if (root.micMenuOpen) return Qt.rgba(255/255, 69/255, 58/255, 0.25);
                        if (!MicrophoneService.isMuted) return Qt.rgba(255/255, 69/255, 58/255, 0.15);
                        return "transparent";
                    }
                    scale: micMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: MicrophoneService.isMuted ? "mic-off" : "mic"
                        size: 14
                        color: {
                            if (root.micMenuOpen || !MicrophoneService.isMuted) return Theme.accentRed;
                            return micMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.35);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
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

                // 4. Interactive Clipboard Button (triggers Clipboard Menu)
                Rectangle {
                    id: clipboardButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.clipboardMenuOpen ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : "transparent"
                    scale: clipboardMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "clipboard"
                        size: 14
                        color: {
                            if (root.clipboardMenuOpen) return Theme.accentBlue;
                            if (ClipboardService.currentText !== "") return Theme.textPrimary;
                            return clipboardMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.35);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: clipboardMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleClipboardMenu()
                    }
                }

                // 5. Interactive Performance Profile Button (triggers Power Profiles Menu)
                Rectangle {
                    id: profileButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.profileMenuOpen ? Qt.rgba(48/255, 209/255, 88/255, 0.25) : "transparent"
                    scale: profileMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: {
                            if (PowerProfileService.activeProfile === "power-saver") return "leaf";
                            if (PowerProfileService.activeProfile === "performance") return "bolt";
                            return "gauge";
                        }
                        size: 14
                        color: {
                            if (root.profileMenuOpen) return Theme.accentGreen;
                            if (PowerProfileService.activeProfile === "performance") return Theme.accentRed;
                            if (PowerProfileService.activeProfile === "power-saver") return Theme.accentGreen;
                            return profileMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.45);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: profileMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleProfileMenu()
                    }
                }

                // 6. Interactive Hardware Resource Stats Button (triggers Mini Stats Menu)
                Rectangle {
                    id: hardwareButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.hardwareMenuOpen ? Qt.rgba(10/255, 132/255, 255/255, 0.25) : "transparent"
                    scale: hardwareMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "cpu"
                        size: 14
                        color: {
                            if (root.hardwareMenuOpen) return Theme.accentBlue;
                            if (HardwareStatsService.cpuPercent > 50) return Theme.accentOrange;
                            return hardwareMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.45);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    MouseArea {
                        id: hardwareMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleHardwareMenu()
                    }
                }

                // 7. Interactive Notification Bell Button (triggers Notification Menu)
                Rectangle {
                    id: notifButton
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.notificationMenuOpen ? Qt.rgba(255/255, 159/255, 10/255, 0.25) : "transparent"
                    scale: notifMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "bell"
                        size: 14
                        color: {
                            if (root.notificationMenuOpen) return Theme.accentOrange;
                            if (NotificationService.unreadCount > 0) return Theme.accentOrange;
                            return notifMouse.containsMouse ? Theme.textPrimary : Qt.rgba(1, 1, 1, 0.38);
                        }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    // Notification unread dot indicator badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.rightMargin: 2
                        width: 7
                        height: 7
                        radius: 3.5
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

                // 8. Interactive iPhone-Style Battery Button (triggers Power Menu)
                Rectangle {
                    id: batteryButton
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: !batteryContent.isPresent ? 26 : (batteryContent.implicitWidth + 8)
                    radius: 13
                    color: {
                        if (root.powerMenuOpen) return !batteryContent.isPresent ? Qt.rgba(255/255, 214/255, 10/255, 0.22) : Qt.rgba(48/255, 209/255, 88/255, 0.2);
                        return "transparent";
                    }
                    scale: batteryMouse.pressed ? 0.90 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    IPhoneBattery {
                        id: batteryContent
                        anchors.centerIn: parent
                        showPercentage: true
                        visible: Theme.showBattery
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
        }

        // Hairline Divider below buttons when morphed open
        Rectangle {
            id: divider
            anchors.top: headerArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: root.anyMenuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }
        }

        // Embedded Morphed Menu Container
        Item {
            id: menuContainer
            anchors.top: divider.bottom
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
                color: Qt.rgba(1, 1, 1, 0.25)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeAllMenus()
            }
        }
    }
}
