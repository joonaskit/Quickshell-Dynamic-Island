import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    // Implicit height of window buffer to accommodate expanded island, status cluster, and quick settings popovers
    implicitHeight: (window.screen && window.screen.height > 0) ? Math.min(window.screen.height - 40, 1150) : 1000

    // Dynamic exclusive zone: when maximized, reserve the top bar space so the maximized window sits under it!
    // When floating, reserve 0 space so windows can move freely.
    exclusiveZone: (window.isMaximized && Theme.reserveSpaceWhenMaximized && !window.hasFullscreenApp) ? Theme.topBarHeight : 0
    aboveWindows: true

    // Top layer sits above regular/maximized windows but below fullscreen windows
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "apple-dynamic-island"

    // Check if the active window is on this screen (or screen is unspecified)
    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }

    // Show full bar whenever any window is maximized
    readonly property bool isMaximized: WindowService.isMaximized && Theme.morphToTopBarWhenMaximized && !window.hasFullscreenApp

    // Friendly application name for the active window
    readonly property string activeAppTitle: isThisScreenActive ? WindowService.activeAppTitle : ""

    // Detect if a fullscreen app (video, game, etc.) is currently active
    readonly property bool hasFullscreenApp: Theme.hideOnFullscreen && WindowService.hasFullscreenApp && isThisScreenActive

    onHasFullscreenAppChanged: {
        if (hasFullscreenApp) {
            if (islandPill.isExpanded) islandPill.collapse();
            statusCluster.closeAllMenus();
            appIndicatorPill.closeContextMenu();
            appCluster.closeMenu();
            virtualDesktopsPill.closeMenu();
        }
    }

    // Top bar hitbox for input masking in top-bar mode
    Item {
        id: topBarHitBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.topBarHeight
        visible: window.isMaximized && !window.hasFullscreenApp

        MouseArea {
            anchors.fill: parent
            enabled: islandPill.isExpanded || islandPill.isSettingsOpen || appCluster.menuOpen
            onClicked: {
                if (islandPill.isExpanded || islandPill.isSettingsOpen) islandPill.collapse();
                if (appCluster.menuOpen) appCluster.closeMenu();
            }
        }
    }

    // Dismiss overlay to close Quick Settings popovers or context menus when clicking anywhere outside
    MouseArea {
        id: dismissOverlay
        anchors.fill: parent
        enabled: statusCluster.anyMenuOpen || appIndicatorPill.contextMenuOpen || appCluster.menuOpen || virtualDesktopsPill.menuOpen
        onClicked: {
            statusCluster.closeAllMenus();
            appIndicatorPill.closeContextMenu();
            appCluster.closeMenu();
            virtualDesktopsPill.closeMenu();
        }
    }

    // Click-through mask: ONLY the pill and its expanded state capture mouse input!
    // In top-bar mode, the full-width top bar also captures clicks.
    // When hidden by fullscreen, mask is empty so 100% of clicks pass through.
    mask: Region {
        Region {
            item: (!window.hasFullscreenApp && window.isMaximized) ? topBarHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp) ? islandPill.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && (!window.isMaximized || statusCluster.anyMenuOpen)) ? statusCluster.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && topLeftEdgeTrigger.visible) ? topLeftEdgeTrigger : null
        }
        Region {
            item: (!window.hasFullscreenApp && appIndicatorEdgeTrigger.visible) ? appIndicatorEdgeTrigger : null
        }
        Region {
            item: (!window.hasFullscreenApp && SettingsService.showWindowControls && appCluster.visible && !window.appClusterShouldHide && (!window.isMaximized || appCluster.menuOpen)) ? appCluster.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && SettingsService.showVirtualDesktops && virtualDesktopsPill.visible && virtualDesktopsPill.desktopCount > 0 && !window.virtualDesktopsShouldHide) ? virtualDesktopsPill.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && virtualDesktopsPill.menuOpen) ? virtualDesktopsPill.menuHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && (statusCluster.anyMenuOpen || appIndicatorPill.contextMenuOpen || appCluster.menuOpen || virtualDesktopsPill.menuOpen)) ? dismissOverlay : null
        }
        Region {
            item: (!window.hasFullscreenApp && SettingsService.showDetachedNotifBubble && notifBubble.visible) ? notifBubble : null
        }
        Region {
            item: (!window.hasFullscreenApp && SettingsService.showAppTrayPill && appIndicatorPill.visible && (appIndicatorPill.appCount > 0 || appIndicatorPill.contextMenuOpen) && !window.appIndicatorShouldHide) ? appIndicatorPill.hitBox : null
        }
    }

    // Auto-hide reveal state for top-left pills (window controls & virtual desktops)
    property bool topLeftRevealed: false

    readonly property bool isTopLeftHovered: edgeHoverHandler.hovered || appCluster.isClusterHovered || virtualDesktopsPill.isPillHovered

    // Dwell timer: user must hold the mouse at the top edge for 220ms before revealing
    Timer {
        id: topLeftDwellTimer
        interval: 220
        repeat: false
        onTriggered: {
            window.topLeftRevealed = true;
        }
    }

    // Unhover timer: keeps the pill down for a moment after mouse leaves
    Timer {
        id: topLeftUnhoverTimer
        interval: 750
        repeat: false
        onTriggered: {
            if (!appCluster.menuOpen && !virtualDesktopsPill.menuOpen) {
                window.topLeftRevealed = false;
            }
        }
    }

    // Target Y coordinates for smooth gliding
    readonly property bool appClusterShouldHide: SettingsService.autoHideWindowControls && !window.topLeftRevealed && !appCluster.menuOpen
    readonly property real appClusterTargetY: {
        if (appClusterShouldHide) return -appCluster.height - 18;
        return window.isMaximized ? 0 : Theme.topMargin;
    }

    readonly property bool virtualDesktopsShouldHide: SettingsService.autoHideVirtualDesktops && !window.topLeftRevealed && !virtualDesktopsPill.menuOpen
    readonly property real virtualDesktopsTargetY: {
        if (virtualDesktopsShouldHide) return -virtualDesktopsPill.height - 18;
        return window.isMaximized ? 0 : Theme.topMargin;
    }

    // Auto-hide reveal state for app indicator pill
    property bool appIndicatorRevealed: false
    readonly property bool isAppIndicatorHovered: appIndicatorEdgeHoverHandler.hovered || appIndicatorPill.isPillHovered

    Timer {
        id: appIndicatorDwellTimer
        interval: 220
        repeat: false
        onTriggered: {
            window.appIndicatorRevealed = true;
        }
    }

    Timer {
        id: appIndicatorUnhoverTimer
        interval: 750
        repeat: false
        onTriggered: {
            if (!appIndicatorPill.contextMenuOpen) {
                window.appIndicatorRevealed = false;
            }
        }
    }

    readonly property bool appIndicatorShouldHide: SettingsService.autoHideAppTrayPill && !window.appIndicatorRevealed && !appIndicatorPill.contextMenuOpen
    readonly property real appIndicatorTargetY: {
        if (appIndicatorShouldHide) return -Math.max(appIndicatorPill.height, Theme.compactHeight) - 24;
        return window.isMaximized ? 0 : Theme.topMargin;
    }

    // Edge trigger strip for top-left pills when auto-hide is enabled
    Item {
        id: topLeftEdgeTrigger
        anchors.top: parent.top
        x: 0
        height: 6
        width: Math.max(160, (appCluster.visible ? (appCluster.x + appCluster.width) : 0) + (virtualDesktopsPill.visible ? (virtualDesktopsPill.width + 16) : 0))
        visible: (SettingsService.autoHideWindowControls && SettingsService.showWindowControls) ||
                 (SettingsService.autoHideVirtualDesktops && SettingsService.showVirtualDesktops)

        HoverHandler {
            id: edgeHoverHandler
            enabled: topLeftEdgeTrigger.visible && !window.hasFullscreenApp
            onHoveredChanged: {
                if (hovered) {
                    topLeftUnhoverTimer.stop();
                    topLeftDwellTimer.start();
                } else {
                    topLeftDwellTimer.stop();
                    if (!window.isTopLeftHovered && !appCluster.menuOpen && !virtualDesktopsPill.menuOpen) {
                        topLeftUnhoverTimer.start();
                    }
                }
            }
        }
    }

    // Edge trigger strip for app indicator pill when auto-hide is enabled
    Item {
        id: appIndicatorEdgeTrigger
        anchors.top: parent.top
        x: appIndicatorPill.x
        height: 6
        width: Math.max(48, appIndicatorPill.width)
        visible: SettingsService.showAppTrayPill && SettingsService.autoHideAppTrayPill && appIndicatorPill.appCount > 0

        HoverHandler {
            id: appIndicatorEdgeHoverHandler
            enabled: appIndicatorEdgeTrigger.visible && !window.hasFullscreenApp
            onHoveredChanged: {
                if (hovered) {
                    appIndicatorUnhoverTimer.stop();
                    appIndicatorDwellTimer.start();
                } else {
                    appIndicatorDwellTimer.stop();
                    if (!window.isAppIndicatorHovered && !appIndicatorPill.contextMenuOpen) {
                        appIndicatorUnhoverTimer.start();
                    }
                }
            }
        }
    }

    // Top Bar Wings (expands left and right when maximized)
    TopBarWings {
        id: topBarWings
        isMaximized: window.isMaximized && !window.hasFullscreenApp
        activeAppTitle: window.activeAppTitle
        currentDate: islandPill.currentDate
        displayBattery: UPower.displayDevice
        compactCenterWidth: islandPill.compactWidth
        opacity: (!window.hasFullscreenApp) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Persistent Application Pill on Top-Left (mirrors Status Cluster on the right)
    TopLeftAppCluster {
        id: appCluster
        anchors.left: parent.left
        anchors.leftMargin: 16
        y: window.appClusterTargetY
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        activeAppTitle: window.activeAppTitle
        activeAppId: WindowService.activeAppId
        opacity: (!window.hasFullscreenApp && SettingsService.showWindowControls) ? 1.0 : 0.0
        visible: opacity > 0.01

        onIsClusterHoveredChanged: {
            if (isClusterHovered) {
                topLeftUnhoverTimer.stop();
            } else if (!window.isTopLeftHovered && !appCluster.menuOpen && !virtualDesktopsPill.menuOpen) {
                topLeftUnhoverTimer.start();
            }
        }

        onMenuOpenChanged: {
            if (!menuOpen && !window.isTopLeftHovered) {
                topLeftUnhoverTimer.start();
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Companion Pill for Virtual Desktops / Workspaces
    VirtualDesktopsPill {
        id: virtualDesktopsPill
        x: (SettingsService.showWindowControls && appCluster.visible) ? (appCluster.x + appCluster.width + 8) : 16
        y: window.virtualDesktopsTargetY
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        opacity: (!window.hasFullscreenApp && SettingsService.showVirtualDesktops) ? 1.0 : 0.0
        visible: opacity > 0.01

        onIsPillHoveredChanged: {
            if (isPillHovered) {
                topLeftUnhoverTimer.stop();
            } else if (!window.isTopLeftHovered && !appCluster.menuOpen && !virtualDesktopsPill.menuOpen) {
                topLeftUnhoverTimer.start();
            }
        }

        onMenuOpenChanged: {
            if (!menuOpen && !window.isTopLeftHovered) {
                topLeftUnhoverTimer.start();
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Dynamic Island container positioned at top center
    IslandPill {
        id: islandPill
        z: (islandPill.isExpanded || islandPill.isSettingsOpen) ? 300 : 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: window.isMaximized ? 0 : Theme.topMargin
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp

        opacity: (!window.hasFullscreenApp) ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Secondary Detached Island Circle (iPhone dual-island notification bubble)
    IslandDetachedBubble {
        id: notifBubble
        anchors.left: islandPill.right
        anchors.leftMargin: 8
        anchors.verticalCenter: islandPill.verticalCenter
        isExpanded: islandPill.isExpanded || islandPill.isSettingsOpen
        isTopBarMode: window.isMaximized

        onClicked: {
            islandPill.expand();
        }
    }

    // Persistent Application Indicator Pill positioned to the left of the notifications group
    AppIndicatorPill {
        id: appIndicatorPill
        anchors.right: statusCluster.left
        anchors.rightMargin: 8
        y: window.appIndicatorTargetY
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        isIslandExpanded: islandPill.isExpanded || islandPill.isSettingsOpen

        onCollapseIslandRequested: {
            islandPill.collapse();
        }

        onIsPillHoveredChanged: {
            if (isPillHovered) {
                appIndicatorUnhoverTimer.stop();
            } else if (!window.isAppIndicatorHovered && !contextMenuOpen) {
                appIndicatorUnhoverTimer.start();
            }
        }

        onContextMenuOpenChanged: {
            if (contextMenuOpen) {
                statusCluster.closeAllMenus();
                appCluster.closeMenu();
                appIndicatorUnhoverTimer.stop();
            } else if (!window.isAppIndicatorHovered) {
                appIndicatorUnhoverTimer.start();
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Connections {
        target: statusCluster
        function onAnyMenuOpenChanged() {
            if (statusCluster.anyMenuOpen) {
                appIndicatorPill.closeContextMenu();
                appCluster.closeMenu();
                virtualDesktopsPill.closeMenu();
            }
        }
    }

    Connections {
        target: appCluster
        function onMenuOpenChanged() {
            if (appCluster.menuOpen) {
                statusCluster.closeAllMenus();
                appIndicatorPill.closeContextMenu();
                virtualDesktopsPill.closeMenu();
                if (islandPill.isExpanded) islandPill.collapse();
            }
        }
    }

    Connections {
        target: islandPill
        function onIsExpandedChanged() {
            if (islandPill.isExpanded) {
                appCluster.closeMenu();
                virtualDesktopsPill.closeMenu();
            }
        }
    }

    Connections {
        target: virtualDesktopsPill
        function onMenuOpenChanged() {
            if (virtualDesktopsPill.menuOpen) {
                statusCluster.closeAllMenus();
                appIndicatorPill.closeContextMenu();
                appCluster.closeMenu();
                if (islandPill.isExpanded || islandPill.isSettingsOpen) islandPill.collapse();
            }
        }
    }

    // iPhone-style Status Cluster positioned at top-right corner
    TopRightStatusCluster {
        id: statusCluster
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: window.isMaximized ? 0 : Theme.topMargin
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        currentDate: islandPill.currentDate

        opacity: (!window.hasFullscreenApp) ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on y {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }

        MouseArea {
            anchors.fill: parent
            enabled: islandPill.isExpanded || islandPill.isSettingsOpen
            onClicked: {
                islandPill.collapse();
            }
        }
    }

    // IPC interface to allow controlling the island from terminal or KDE Plasma shortcuts
    // E.g.: `quickshell ipc call island toggle`
    IpcHandler {
        target: "island"

        function toggle() {
            islandPill.toggle();
        }

        function expand() {
            islandPill.expand();
        }

        function collapse() {
            islandPill.collapse();
        }

        function toggleCaffeine() {
            CaffeineService.toggle();
        }
    }
}
