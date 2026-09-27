import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool isTopBarMode: false
    property string activeAppTitle: ""
    property string activeAppId: WindowService.activeAppId
    property string activeWindowTitle: WindowService.activeWindowTitle
    property string activeWindowId: WindowService.activeWindowId
    property var openWindows: WindowService.getAppWindows(activeAppId)

    readonly property bool isDesktop: (!activeAppTitle || activeAppTitle === "Desktop" || activeAppId === "")

    property bool menuOpen: false
    z: root.menuOpen ? 200 : 15

    property alias hitBox: clusterBackground

    function toggleMenu() {
        root.menuOpen = !root.menuOpen;
    }

    function closeMenu() {
        root.menuOpen = false;
    }

    onActiveAppIdChanged: {
        // If the focused app changes while open, close the menu smoothly
        if (root.menuOpen) {
            root.closeMenu();
        }
    }

    // Hover state matching IslandPill
    readonly property bool isHovered: headerMouse.containsMouse && !root.menuOpen

    // Dimensions
    readonly property real compactWidth: contentRow.implicitWidth + (root.isTopBarMode ? 20 : 28) + (root.isHovered ? 8 : 0)
    readonly property real expandedWidth: Math.max(275, compactWidth)
    readonly property real targetWidth: root.menuOpen ? expandedWidth : compactWidth

    readonly property real compactHeight: root.isTopBarMode ? (Theme.topBarHeight + 1) : Theme.compactHeight
    readonly property real menuContentHeight: menuColumn.implicitHeight

    readonly property real targetHeight: {
        if (!root.menuOpen) return compactHeight;
        if (root.isTopBarMode) return compactHeight + 1 + menuContentHeight + 22;
        return 42 + menuContentHeight + 22;
    }

    readonly property real targetTopRadius: {
        if (root.isTopBarMode) return 0;
        return root.menuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    readonly property real targetBottomRadius: {
        if (root.isTopBarMode) return root.menuOpen ? 18 : 0;
        return root.menuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    implicitWidth: clusterBackground.width
    implicitHeight: clusterBackground.height

    // Ambient drop shadow, morphing with the capsule
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
        opacity: (root.isTopBarMode && !root.menuOpen) ? 0.0 : (root.menuOpen ? 0.65 : 0.45)
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Morphed Background capsule: seamlessly connects to top bar when maximized, or acts as pill when floating
    Rectangle {
        id: clusterBackground
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.targetWidth
        height: root.targetHeight
        clip: true

        topLeftRadius: root.targetTopRadius
        topRightRadius: root.targetTopRadius
        bottomLeftRadius: root.targetBottomRadius
        bottomRightRadius: root.targetBottomRadius

        color: (root.isTopBarMode && !root.menuOpen) ? "transparent" : Theme.islandBackground
        border.width: 0
        border.color: "transparent"

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Theme.animEasing
                easing.overshoot: Theme.animOvershoot
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: root.isTopBarMode ? 260 : Theme.animDuration
                easing.type: (!root.isTopBarMode && root.menuOpen) ? Theme.animEasing : Easing.OutCubic
                easing.overshoot: (!root.isTopBarMode && root.menuOpen) ? Theme.animOvershoot : 1.0
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

        // Top Header Area (always visible, interactive pill header)
        Item {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.compactHeight

            // No harsh color flash on hover; the pill expands physically like IslandPill

            RowLayout {
                id: contentRow
                anchors.left: parent.left
                anchors.leftMargin: root.isTopBarMode ? 10 : (root.menuOpen ? 14 : 12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                // App Icon
                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    Image {
                        id: appIconImg
                        anchors.fill: parent
                        source: WindowService.resolveAppIcon(root.activeAppId)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: root.isDesktop ? "desktop" : "window"
                        size: 14
                        color: Theme.accentBlue
                        visible: !appIconImg.visible
                    }
                }

                // App Name
                Text {
                    text: root.activeAppTitle.length > 0 ? root.activeAppTitle : "Desktop"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.maximumWidth: root.menuOpen ? 200 : 130
                }

                // Dropdown Chevron
                SvgIcon {
                    name: "chevron-down"
                    size: 9
                    color: (headerMouse.containsMouse || root.menuOpen) ? Theme.textPrimary : Theme.textTertiary
                    opacity: 0.8
                    rotation: root.menuOpen ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.toggleMenu()
            }
        }

        // Sleek Divider under Header
        Rectangle {
            id: divider
            anchors.top: headerArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: root.menuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }
        }

        // Menu Container
        Item {
            id: menuContainer
            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: grabberArea.top
            anchors.topMargin: 4
            clip: true
            opacity: root.menuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 3

                // Window Title Caption (shows active window title or status)
                Item {
                    width: parent.width
                    height: 20
                    visible: !root.isDesktop && root.activeWindowTitle.length > 0

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.activeWindowTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                // Window Actions Section Label
                Item {
                    width: parent.width
                    height: 16
                    visible: !root.isDesktop

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WINDOW"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "restore"
                    iconColor: Theme.accentBlue
                    label: "Unmaximize (Float)"
                    onClicked: {
                        WindowService.unmaximizeWindow(root.activeWindowId || root.activeAppId);
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "minimize"
                    iconColor: Theme.textSecondary
                    label: "Minimize"
                    onClicked: {
                        WindowService.minimizeWindow(root.activeWindowId || root.activeAppId);
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "pin"
                    iconColor: Theme.accentOrange
                    label: "Always on Top"
                    onClicked: {
                        WindowService.toggleKeepAbove(root.activeWindowId || root.activeAppId);
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "desktop"
                    iconColor: Theme.accentPurple
                    label: "Move to Next Desktop"
                    onClicked: {
                        WindowService.moveToNextDesktop(root.activeWindowId || root.activeAppId);
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "close"
                    iconColor: Theme.accentRed
                    label: "Close Window"
                    isDestructive: true
                    onClicked: {
                        WindowService.closeWindow(root.activeWindowId || root.activeAppId);
                        root.closeMenu();
                    }
                }

                // Open Windows List (if 2+ windows of this app exist)
                Rectangle {
                    visible: !root.isDesktop && root.openWindows.length > 1
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Item {
                    width: parent.width
                    height: 16
                    visible: !root.isDesktop && root.openWindows.length > 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WINDOWS (" + root.openWindows.length + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }
                }

                Repeater {
                    model: (!root.isDesktop && root.openWindows.length > 1) ? root.openWindows : []

                    MenuItem {
                        required property var modelData
                        iconName: "window"
                        iconColor: (modelData.id === root.activeWindowId || modelData.active) ? Theme.accentBlue : Theme.textTertiary
                        label: modelData.title && modelData.title.length > 0 ? modelData.title : (root.activeAppTitle + " Window")
                        badgeText: (modelData.id === root.activeWindowId || modelData.active) ? "Active" : ""
                        isActive: (modelData.id === root.activeWindowId || modelData.active)
                        onClicked: {
                            WindowService.activateWindow(modelData.id);
                            root.closeMenu();
                        }
                    }
                }

                // Application Lifecycle Section
                Rectangle {
                    visible: !root.isDesktop
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Item {
                    width: parent.width
                    height: 16
                    visible: !root.isDesktop

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "APPLICATION"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "plus"
                    iconColor: Theme.accentGreen
                    label: "New Window"
                    onClicked: {
                        WindowService.launchNewWindow(root.activeAppId);
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: !root.isDesktop
                    iconName: "power"
                    iconColor: Theme.accentRed
                    label: "Quit " + root.activeAppTitle
                    isDestructive: true
                    onClicked: {
                        WindowService.quitApplication(root.activeAppId);
                        root.closeMenu();
                    }
                }

                // Desktop Shortcuts Section (when Desktop is focused)
                Item {
                    width: parent.width
                    height: 16
                    visible: root.isDesktop

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DESKTOP SHORTCUTS"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textTertiary
                    }
                }

                MenuItem {
                    visible: root.isDesktop
                    iconName: "terminal"
                    iconColor: Theme.accentCyan
                    label: "Terminal"
                    onClicked: {
                        WindowService.openTerminal();
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: root.isDesktop
                    iconName: "folder"
                    iconColor: Theme.accentBlue
                    label: "Files (Dolphin)"
                    onClicked: {
                        WindowService.openFileManager();
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: root.isDesktop
                    iconName: "settings"
                    iconColor: Theme.accentOrange
                    label: "System Settings"
                    onClicked: {
                        WindowService.openSettings();
                        root.closeMenu();
                    }
                }

                MenuItem {
                    visible: root.isDesktop
                    iconName: "lock"
                    iconColor: Theme.accentYellow
                    label: "Lock Screen"
                    onClicked: {
                        WindowService.lockScreen();
                        root.closeMenu();
                    }
                }
            }
        }

        // Bottom grabber pill (matches TopRightStatusCluster)
        Rectangle {
            id: grabberArea
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 7
            width: 36
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.2)
            opacity: root.menuOpen ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }
        }
    }

    // Reusable Menu Item Component
    component MenuItem: Rectangle {
        id: itemRoot
        property string iconName: ""
        property string label: ""
        property string badgeText: ""
        property color iconColor: Theme.textSecondary
        property color textColor: Theme.textPrimary
        property bool isDestructive: false
        property bool isActive: false
        signal clicked()

        width: parent ? parent.width : 255
        height: 28
        radius: 7
        scale: mouse.pressed ? 0.98 : (mouse.containsMouse ? 1.02 : 1.0)
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animDurationFast
                easing.type: Theme.animEasing
                easing.overshoot: Theme.animOvershoot
            }
        }
        color: mouse.containsMouse
            ? (isDestructive ? Qt.rgba(1, 0.27, 0.23, 0.20) : Qt.rgba(1, 1, 1, 0.12))
            : (isActive ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            SvgIcon {
                name: itemRoot.iconName
                size: 14
                color: itemRoot.isDestructive
                    ? (mouse.containsMouse ? Theme.accentRed : Theme.textSecondary)
                    : itemRoot.iconColor
                visible: itemRoot.iconName !== ""
            }

            Text {
                Layout.fillWidth: true
                text: itemRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: itemRoot.isActive ? Font.DemiBold : Font.Normal
                color: itemRoot.isDestructive
                    ? (mouse.containsMouse ? Theme.accentRed : Theme.textPrimary)
                    : itemRoot.textColor
                elide: Text.ElideRight
            }

            Text {
                text: itemRoot.badgeText
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.accentBlue
                visible: itemRoot.badgeText !== ""
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: itemRoot.clicked()
        }
    }
}
