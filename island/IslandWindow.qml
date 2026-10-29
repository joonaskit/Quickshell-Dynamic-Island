import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower

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
    // When floating, reserve 0 space so windows can move freely, or with reserveSpaceWithoutBar a fixed gap
    // below the pills. An auto-hidden bar reserves nothing.
    exclusiveZone: {
        if (SettingsService.autoHideTopBar || window.hasFullscreenApp) return 0;
        if (window.isMaximized) return Theme.reserveSpaceWhenMaximized ? Theme.topBarHeight : 0;
        return SettingsService.reserveSpaceWithoutBar ? window.floatingGap : 0;
    }
    // Space the floating pills take from the top edge
    readonly property int floatingGap: (Theme.notchStyle ? 0 : Theme.topMargin) + Theme.compactHeight
    aboveWindows: true

    // Top layer sits above regular/maximized windows but below fullscreen windows
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-island"
    // Lets notification replies and menus with text fields take typing once clicked
    WlrLayershell.keyboardFocus: (islandPill.isNotificationOpen || statusCluster.notificationMenuOpen || statusCluster.hueMenuOpen || statusCluster.nightMenuOpen || statusCluster.kdeMenuOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Check if the active window is on this screen (or screen is unspecified)
    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }

    // Check if any window on this screen is tiled (split screen) or spans from top to bottom
    readonly property bool hasTiledWindow: {
        if (!WindowService.windowList || WindowService.windowList.length === 0) return false;
        let scrName = (window.screen && window.screen.name) ? window.screen.name : "";
        let scrW = (window.screen && window.screen.width > 0) ? window.screen.width : 1920;
        let scrH = (window.screen && window.screen.height > 0) ? window.screen.height : 1080;
        let scrX = (window.screen && window.screen.x !== undefined) ? window.screen.x : 0;
        let scrY = (window.screen && window.screen.y !== undefined) ? window.screen.y : 0;

        for (let i = 0; i < WindowService.windowList.length; i++) {
            let w = WindowService.windowList[i];
            if (!w || w.minimized || w.onCurrent === false || w.moving) continue;
            let wApp = (w.app || "").toLowerCase();
            if (wApp === "quickshell" || wApp === "plasmashell" || wApp === "org.kde.plasmashell") continue;
            if (w.screen && scrName && w.screen !== scrName) continue;

            // Explicitly tiled window in KWin (QuickTile or Custom Tiling)
            if (w.tiled) return true;

            // Geometry check: window manually placed going from top to bottom of screen (vertical split)
            let wx = w.x !== undefined ? w.x : 0;
            let wy = w.y !== undefined ? w.y : 9999;
            let ww = w.width !== undefined ? w.width : 0;
            let wh = w.height !== undefined ? w.height : 0;
            if (scrY > 0 && wy < scrY && (wy + wh) <= scrH) wy += scrY;
            if (scrX > 0 && wx < scrX && (wx + ww) <= scrW) wx += scrX;

            // A tile sits below the top bar or the floating gap once they reserve space, so allow
            // for that height too, or the bar would flip the window between the two positions
            let reserved = SettingsService.reserveSpaceWithoutBar ? Math.max(Theme.topBarHeight, window.floatingGap) : Theme.topBarHeight;
            let touchesTop = (wy <= (scrY + reserved + 8));
            let reachesBottom = ((wy + wh) >= (scrY + scrH - 80));
            let isSplitWidth = (ww >= (scrW * 0.25) && ww <= (scrW * 0.85));

            if (touchesTop && reachesBottom && isSplitWidth) return true;
        }
        return false;
    }

    // Show full bar whenever any window is maximized or tiled/split, or always with alwaysTopBar
    readonly property bool isMaximized: (SettingsService.alwaysTopBar || (((WindowService.isMaximized && isThisScreenActive) || hasTiledWindow) && Theme.morphToTopBarWhenMaximized)) && !window.hasFullscreenApp

    // Friendly application name for the active window
    readonly property string activeAppTitle: isThisScreenActive ? WindowService.activeAppTitle : ""

    // Detect if a fullscreen app (video, game, etc.) is currently active
    readonly property bool hasFullscreenApp: Theme.hideOnFullscreen && WindowService.hasFullscreenApp && isThisScreenActive

    onHasFullscreenAppChanged: {
        if (hasFullscreenApp) {
            if (islandPill.isOpen) islandPill.collapse();
            statusCluster.closeAllMenus();
            appIndicatorPill.closeContextMenu();
            appCluster.closeMenu();
            virtualDesktopsPill.closeMenu();
        }
    }

    // Auto-hide of the whole bar: it slides up off screen until the pointer rests at the top
    // edge. Open popups and the expanded island keep it down.
    property bool barRevealed: false
    readonly property bool barHidden: SettingsService.autoHideTopBar && !window.barRevealed && !window.hasDismissablePopup && !islandPill.isOpen
    // With the bar down, the pills that auto-hide on their own come down with it
    readonly property bool barDown: SettingsService.autoHideTopBar && !window.barHidden
    readonly property real barHideOffset: window.barHidden ? Theme.topMargin + Theme.compactHeight + Theme.px(24) : 0

    Timer {
        id: barDwellTimer
        interval: 220
        onTriggered: window.barRevealed = true
    }

    Timer {
        id: barUnhoverTimer
        interval: 750
        onTriggered: window.barRevealed = false
    }

    // Watches the top edge while the bar is hidden and the bar's height while it is down. Above
    // the pills, whose own hover areas would take the event; it only watches, clicks pass.
    Item {
        id: barHoverArea
        z: 500
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: window.barHidden ? Math.max(8, Theme.px(8)) : Math.max(Theme.topBarHeight + Theme.topMargin, window.floatingGap)

        HoverHandler {
            enabled: SettingsService.autoHideTopBar && !window.hasFullscreenApp
            blocking: false
            onHoveredChanged: {
                if (hovered) {
                    barUnhoverTimer.stop();
                    if (!window.barRevealed) barDwellTimer.start();
                } else {
                    barDwellTimer.stop();
                    barUnhoverTimer.start();
                }
            }
        }
    }

    // Top bar hitbox for input masking in top-bar mode
    Item {
        id: topBarHitBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.topBarHeight
        visible: window.isMaximized && !window.hasFullscreenApp && !window.barHidden

        MouseArea {
            anchors.fill: parent
            enabled: islandPill.isOpen || appCluster.menuOpen
            onClicked: {
                if (islandPill.isOpen) islandPill.collapse();
                if (appCluster.menuOpen) appCluster.closeMenu();
            }
        }
    }

    // The expanded island and an opened notification close on an outside click, like the menus
    readonly property bool expandedDismissable: islandPill.isExpanded || islandPill.isNotificationOpen
    readonly property bool hasDismissablePopup: statusCluster.anyMenuOpen || appIndicatorPill.contextMenuOpen || appCluster.menuOpen || virtualDesktopsPill.menuOpen || expandedDismissable

    // Dismiss overlay to close the expanded island, Quick Settings popovers or context menus when clicking anywhere outside
    MouseArea {
        id: dismissOverlay
        anchors.fill: parent
        enabled: window.hasDismissablePopup
        onClicked: {
            statusCluster.closeAllMenus();
            appIndicatorPill.closeContextMenu();
            appCluster.closeMenu();
            virtualDesktopsPill.closeMenu();
            if (window.expandedDismissable) islandPill.collapse();
        }
    }

    // A mask region on a pill's hitBox, placed by hand. A Region that follows an item updates
    // only when the item itself moves, not when its pill slides (the bar coming down, a pill
    // auto-hiding), so it would stay where the pill was. A null box drops out.
    component PillRegion: Region {
        property Item pill: null
        property Item box: null
        x: box ? Math.floor(pill.x + box.x) : 0
        y: box ? Math.floor(pill.y + box.y) : 0
        width: box ? Math.ceil(box.width) : 0
        height: box ? Math.ceil(box.height) : 0
    }

    // Click-through mask: ONLY the pill and its expanded state capture mouse input!
    // In top-bar mode, the full-width top bar also captures clicks.
    // When hidden by fullscreen, mask is empty so 100% of clicks pass through.
    mask: Region {
        Region {
            item: (!window.hasFullscreenApp && window.isMaximized && !window.barHidden) ? topBarHitBox : null
        }
        // The edge strip that reveals a hidden bar
        Region {
            item: (!window.hasFullscreenApp && window.barHidden) ? barHoverArea : null
        }
        // The tab hover areas, so the gap beside a slid-out tab still counts as over it
        Region {
            item: (window.tabsEnabled && SettingsService.showAppTrayPill && appIndicatorPill.visible && !window.appIndicatorShouldHide) ? appTabHoverArea : null
        }
        Region {
            item: (window.tabsEnabled && SettingsService.showVirtualDesktops && virtualDesktopsPill.visible && !window.virtualDesktopsShouldHide) ? desktopsTabHoverArea : null
        }
        PillRegion {
            pill: islandPill
            box: (!window.hasFullscreenApp) ? islandPill.hitBox : null
        }
        PillRegion {
            pill: statusCluster
            box: (!window.hasFullscreenApp && (!window.isMaximized || statusCluster.anyMenuOpen)) ? statusCluster.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && topLeftEdgeTrigger.visible) ? topLeftEdgeTrigger : null
        }
        Region {
            item: (!window.hasFullscreenApp && appIndicatorEdgeTrigger.visible) ? appIndicatorEdgeTrigger : null
        }
        PillRegion {
            pill: appCluster
            box: (!window.hasFullscreenApp && SettingsService.showWindowControls && appCluster.visible && !window.appClusterShouldHide && (!window.isMaximized || appCluster.menuOpen)) ? appCluster.hitBox : null
        }
        PillRegion {
            pill: virtualDesktopsPill
            box: (!window.hasFullscreenApp && SettingsService.showVirtualDesktops && virtualDesktopsPill.visible && virtualDesktopsPill.desktopCount > 0 && !window.virtualDesktopsShouldHide) ? virtualDesktopsPill.hitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && virtualDesktopsPill.menuOpen) ? virtualDesktopsPill.menuHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && window.hasDismissablePopup) ? dismissOverlay : null
        }
        Region {
            item: (!window.hasFullscreenApp && SettingsService.showDetachedNotifBubble && notifBubble.visible) ? notifBubble : null
        }
        PillRegion {
            pill: appIndicatorPill
            box: (!window.hasFullscreenApp && SettingsService.showAppTrayPill && appIndicatorPill.visible && (appIndicatorPill.appCount > 0 || appIndicatorPill.contextMenuOpen) && !window.appIndicatorShouldHide) ? appIndicatorPill.hitBox : null
        }
    }

    // Auto-hide reveal state for top-left pills (window controls & virtual desktops)
    property bool topLeftRevealed: false

    readonly property bool isTopLeftHovered: edgeHoverHandler.hovered || appCluster.isClusterHovered || virtualDesktopsPill.isPillHovered

    onIsTopLeftHoveredChanged: {
        if (isTopLeftHovered) {
            topLeftUnhoverTimer.stop();
        } else {
            topLeftDwellTimer.stop();
            if (!appCluster.menuOpen && !virtualDesktopsPill.menuOpen) {
                topLeftUnhoverTimer.start();
            }
        }
    }

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

    // Notch style, tab effect: the app tray tucks half behind the status icons and the
    // virtual desktops half behind the window controls until the pointer is over the
    // part that shows. A short hold keeps a tab out while the pointer crosses to it.
    readonly property bool tabsEnabled: Theme.notchStyle && SettingsService.tuckPills && !window.isMaximized && !window.hasFullscreenApp
    readonly property bool appTabOut: appTabHover.hovered || appIndicatorPill.contextMenuOpen || appTabHold.running
    readonly property bool appTabTucked: window.tabsEnabled && statusCluster.width > 0 && !window.appIndicatorShouldHide && !window.appTabOut
    readonly property bool desktopsTabOut: desktopsTabHover.hovered || virtualDesktopsPill.menuOpen || desktopsTabHold.running
    readonly property bool desktopsTabTucked: window.tabsEnabled && SettingsService.showWindowControls && appCluster.visible && !window.appClusterShouldHide && !window.virtualDesktopsShouldHide && !window.desktopsTabOut

    Timer {
        id: appTabHold
        interval: 350
    }

    Timer {
        id: desktopsTabHold
        interval: 350
    }

    // Hovering a tab, also the half under its neighbour, pushes it out. Above every pill,
    // since the pills' own hover areas take the event before anything under them; it only
    // watches hover, so clicks still reach the pills.
    // Each area always reaches from the tab's outer edge to where its tucked half ends under
    // the neighbour, so it covers both the tucked and the slid-out tab and the gap between.
    // An area that moved with the tab would slide away from a pointer near the seam, tuck the
    // tab back under it and reveal it again, over and over.
    Item {
        id: appTabHoverArea
        readonly property real tuckedEnd: statusCluster.x + Math.round(appIndicatorPill.width * 0.5)
        z: 500
        x: appIndicatorPill.x
        y: appIndicatorPill.y
        width: Math.max(appIndicatorPill.width, tuckedEnd - appIndicatorPill.x)
        height: appIndicatorPill.height

        HoverHandler {
            id: appTabHover
            enabled: window.tabsEnabled
            blocking: false
            onHoveredChanged: if (!hovered) appTabHold.restart()
        }
    }

    Item {
        id: desktopsTabHoverArea
        readonly property real tuckedStart: appCluster.x + appCluster.width - Math.round(virtualDesktopsPill.width * 0.5)
        z: 500
        x: Math.min(virtualDesktopsPill.x, tuckedStart)
        y: virtualDesktopsPill.y
        width: virtualDesktopsPill.x + virtualDesktopsPill.width - x
        height: virtualDesktopsPill.height

        HoverHandler {
            id: desktopsTabHover
            enabled: window.tabsEnabled
            blocking: false
            onHoveredChanged: if (!hovered) desktopsTabHold.restart()
        }
    }

    // Glow along the seam where the virtual desktops go under the window controls.
    // Between the two: the pill is at z 0 and the window controls at 15.
    TabSeamGlow {
        z: 1
        active: window.desktopsTabTucked && virtualDesktopsPill.visible
        tab: virtualDesktopsPill.hitBox
        tabX: virtualDesktopsPill.x + virtualDesktopsPill.hitBox.x
        tabY: virtualDesktopsPill.y + virtualDesktopsPill.hitBox.y
        front: appCluster.hitBox
        frontX: appCluster.x + appCluster.hitBox.x
        frontY: appCluster.y + appCluster.hitBox.y
        toRight: true
        accentColor: Theme.accentCyan
    }

    // Resting top of the pills: flush in the top bar, one pixel above the screen in notch
    // style (so the body's top border is off screen), else hanging below the edge
    readonly property real pillTopY: (window.isMaximized ? 0 : (Theme.notchStyle ? -1 : Theme.topMargin)) - window.barHideOffset

    // Target Y coordinates for smooth gliding
    readonly property bool appClusterShouldHide: SettingsService.autoHideWindowControls && !window.barDown && !window.topLeftRevealed && !appCluster.menuOpen
    readonly property real appClusterTargetY: {
        if (appClusterShouldHide) return -appCluster.height - 18;
        return window.pillTopY;
    }

    readonly property bool virtualDesktopsShouldHide: SettingsService.autoHideVirtualDesktops && !window.barDown && !window.topLeftRevealed && !virtualDesktopsPill.menuOpen
    readonly property real virtualDesktopsTargetY: {
        if (virtualDesktopsShouldHide) return -virtualDesktopsPill.height - 18;
        return window.pillTopY;
    }

    // Auto-hide reveal state for app indicator pill
    property bool appIndicatorRevealed: false
    readonly property bool isAppIndicatorHovered: appIndicatorEdgeHoverHandler.hovered || appIndicatorPill.pointerOver || appTabHover.hovered

    onIsAppIndicatorHoveredChanged: {
        if (isAppIndicatorHovered) {
            appIndicatorUnhoverTimer.stop();
        } else {
            appIndicatorDwellTimer.stop();
            if (!appIndicatorPill.contextMenuOpen) {
                appIndicatorUnhoverTimer.start();
            }
        }
    }

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

    readonly property bool appIndicatorShouldHide: SettingsService.autoHideAppTrayPill && !window.barDown && !window.appIndicatorRevealed && !appIndicatorPill.contextMenuOpen
    readonly property real appIndicatorTargetY: {
        if (appIndicatorShouldHide) return -Math.max(appIndicatorPill.height, Theme.compactHeight) - 24;
        return window.pillTopY;
    }

    // Edge trigger strip for top-left pills when auto-hide is enabled
    Item {
        id: topLeftEdgeTrigger
        anchors.top: parent.top
        x: 0
        height: Math.max(8, Theme.px(8))
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
                }
            }
        }
    }

    // Edge trigger strip for app indicator pill when auto-hide is enabled
    Item {
        id: appIndicatorEdgeTrigger
        anchors.top: parent.top
        x: appIndicatorPill.x
        height: Math.max(8, Theme.px(8))
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
                }
            }
        }
    }

    // Elegant ambient glows for hidden elements when mouse comes near
    HiddenElementGlow {
        id: appClusterGlow
        z: 10
        targetX: appCluster.x
        targetWidth: appCluster.width
        active: window.appClusterShouldHide && SettingsService.showWindowControls && !window.hasFullscreenApp && edgeHoverHandler.hovered
        accentColor: Theme.accent
    }

    HiddenElementGlow {
        id: virtualDesktopsGlow
        z: 10
        targetX: virtualDesktopsPill.x
        targetWidth: virtualDesktopsPill.width
        active: window.virtualDesktopsShouldHide && SettingsService.showVirtualDesktops && (virtualDesktopsPill.desktopCount > 0) && !window.hasFullscreenApp && edgeHoverHandler.hovered
        accentColor: Theme.accentCyan
    }

    HiddenElementGlow {
        id: appIndicatorGlow
        z: 10
        targetX: appIndicatorPill.x
        targetWidth: appIndicatorPill.width
        active: window.appIndicatorShouldHide && SettingsService.showAppTrayPill && (appIndicatorPill.appCount > 0) && !window.hasFullscreenApp && appIndicatorEdgeHoverHandler.hovered
        accentColor: Theme.accent
    }


    // Top Bar Wings (expands left and right when maximized)
    TopBarWings {
        id: topBarWings
        anchors.topMargin: -window.barHideOffset
        isMaximized: window.isMaximized && !window.hasFullscreenApp
        activeAppTitle: window.activeAppTitle
        currentDate: islandPill.currentDate
        displayBattery: UPower.displayDevice
        compactCenterWidth: islandPill.compactWidth
        gaps: [islandPill.barGap, statusCluster.barGap, appCluster.barGap, appIndicatorPill.barGap].filter(g => g)
        opacity: (!window.hasFullscreenApp) ? 1.0 : 0.0

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

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
        barEdge: topBarWings.edgeDepth
        hasFullscreenApp: window.hasFullscreenApp
        activeAppTitle: window.activeAppTitle
        activeAppId: WindowService.activeAppId
        opacity: (!window.hasFullscreenApp && SettingsService.showWindowControls) ? 1.0 : 0.0
        visible: opacity > 0.01

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
        x: (SettingsService.showWindowControls && appCluster.visible) ? (appCluster.x + appCluster.width + (window.desktopsTabTucked ? -Math.round(virtualDesktopsPill.width * 0.5) : 8)) : 16
        y: window.virtualDesktopsTargetY
        isSlidOut: !window.virtualDesktopsShouldHide && !window.barHidden
        isTopBarMode: window.isMaximized
        hasFullscreenApp: window.hasFullscreenApp
        opacity: (!window.hasFullscreenApp && SettingsService.showVirtualDesktops) ? 1.0 : 0.0
        visible: opacity > 0.01

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

    // Island container positioned at top center
    IslandPill {
        id: islandPill
        z: (islandPill.isOpen) ? 300 : 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: window.pillTopY
        isTopBarMode: window.isMaximized
        barEdge: topBarWings.edgeDepth
        hasFullscreenApp: window.hasFullscreenApp

        opacity: (!window.hasFullscreenApp) ? 1.0 : 0.0
        visible: opacity > 0.01

        onRequestShowAllNotifications: {
            islandPill.collapse();
            statusCluster.openNotificationMenu();
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

    // Secondary Detached Island Circle (dual-island notification bubble)
    IslandDetachedBubble {
        id: notifBubble
        // Tracks the pill body's actual animated right edge (same frame, same curve)
        x: islandPill.x + islandPill.hitBox.x + islandPill.hitBox.width + 8
        anchors.verticalCenter: islandPill.verticalCenter
        isExpanded: islandPill.isOpen
        isTopBarMode: window.isMaximized

        onClicked: {
            if (islandPill.isOpen) {
                islandPill.collapse();
            }
            statusCluster.openNotificationMenu();
        }
    }

    // Persistent Application Indicator Pill positioned to the left of the notifications group
    AppIndicatorPill {
        id: appIndicatorPill
        anchors.right: statusCluster.left
        anchors.rightMargin: window.appTabTucked ? -Math.round(appIndicatorPill.width * 0.5) : 8
        y: window.appIndicatorTargetY
        isTopBarMode: window.isMaximized
        barEdge: topBarWings.edgeDepth
        hasFullscreenApp: window.hasFullscreenApp
        isIslandExpanded: islandPill.isOpen

        onCollapseIslandRequested: {
            islandPill.collapse();
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

        Behavior on anchors.rightMargin {
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
                if (islandPill.isOpen) islandPill.collapse();
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
                if (islandPill.isOpen) islandPill.collapse();
            }
        }
    }

    // Glow along the seam where the app tray goes under the status icons. Both are at
    // z 1, so it is declared between them to sit above the tray and below the icons.
    TabSeamGlow {
        z: 1
        active: window.appTabTucked && appIndicatorPill.visible
        tab: appIndicatorPill.hitBox
        tabX: appIndicatorPill.x + appIndicatorPill.hitBox.x
        tabY: appIndicatorPill.y + appIndicatorPill.hitBox.y
        front: statusCluster.hitBox
        frontX: statusCluster.x + statusCluster.hitBox.x
        frontY: statusCluster.y + statusCluster.hitBox.y
        toRight: false
        accentColor: Theme.accent
    }

    // Status Cluster positioned at top-right corner
    TopRightStatusCluster {
        id: statusCluster
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: window.pillTopY
        isTopBarMode: window.isMaximized
        barEdge: topBarWings.edgeDepth
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
            enabled: islandPill.isOpen
            onClicked: {
                islandPill.collapse();
            }
        }
    }

    // Frosted glass behind the pills and their menus on the light scheme
    WindowBlur {
        target: window
        items: [
            topBarWings.bar,
            islandPill.blurBody,
            islandPill.earsBlur,
            statusCluster.blurBody,
            statusCluster.earsBlur,
            appCluster.blurBody,
            appCluster.earsBlur,
            appIndicatorPill.blurBody,
            virtualDesktopsPill.hitBox,
            virtualDesktopsPill.ears,
            virtualDesktopsPill.menuBody,
            notifBubble.body
        ]
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
