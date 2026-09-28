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
            enabled: islandPill.isExpanded || appCluster.menuOpen
            onClicked: {
                if (islandPill.isExpanded) islandPill.collapse();
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
            item: (!window.hasFullscreenApp && (!window.isMaximized || appCluster.menuOpen)) ? appCluster.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && virtualDesktopsPill.visible && virtualDesktopsPill.desktopCount > 0) ? virtualDesktopsPill.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && virtualDesktopsPill.menuOpen) ? virtualDesktopsPill.menuHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && (statusCluster.anyMenuOpen || appIndicatorPill.contextMenuOpen || appCluster.menuOpen || virtualDesktopsPill.menuOpen)) ? dismissOverlay : null
        }
        Region {
            item: (!window.hasFullscreenApp && notifBubble.visible) ? notifBubble : null
        }
        Region {
            item: (!window.hasFullscreenApp && appIndicatorPill.visible && (appIndicatorPill.appCount > 0 || appIndicatorPill.contextMenuOpen)) ? appIndicatorPill.hitBox : null
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
        y: window.isMaximized ? 0 : Theme.topMargin
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        activeAppTitle: window.activeAppTitle
        activeAppId: WindowService.activeAppId
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

    // Companion Pill for Virtual Desktops / Workspaces
    VirtualDesktopsPill {
        id: virtualDesktopsPill
        anchors.left: appCluster.right
        anchors.leftMargin: 8
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

    // Dynamic Island container positioned at top center
    IslandPill {
        id: islandPill
        z: islandPill.isExpanded ? 300 : 20
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
        isExpanded: islandPill.isExpanded
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
        y: window.isMaximized ? 0 : Theme.topMargin
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        isIslandExpanded: islandPill.isExpanded

        onCollapseIslandRequested: {
            islandPill.collapse();
        }

        onContextMenuOpenChanged: {
            if (contextMenuOpen) {
                statusCluster.closeAllMenus();
                appCluster.closeMenu();
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
                if (islandPill.isExpanded) islandPill.collapse();
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
            enabled: islandPill.isExpanded
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
