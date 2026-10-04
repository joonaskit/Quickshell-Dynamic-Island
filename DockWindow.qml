import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"

    readonly property bool isVertical: Theme.dockPosition === "left" || Theme.dockPosition === "right"
    readonly property string dockPosition: Theme.dockPosition

    anchors {
        bottom: window.dockPosition === "bottom" || window.isVertical
        top: window.isVertical
        left: window.dockPosition !== "right"
        right: window.dockPosition !== "left"
    }

    implicitHeight: window.isVertical ? (window.screen ? window.screen.height : 1080) : 520
    implicitWidth: window.isVertical ? 520 : (window.screen ? window.screen.width : 1920)

    // Reserve space at dock screen edge if configured in Theme and not hidden
    exclusiveZone: (Theme.dockReserveSpace && !window.shouldDropDock) ? (Theme.dockHeight + Theme.dockBottomMargin) : 0
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: dockBar.appPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Check if this screen is active or primary
    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }

    // Auto-hide when a fullscreen window (game, video, presentation) is active
    readonly property bool hasFullscreenApp: Theme.dockAutoHideOnFullscreen && WindowService.hasFullscreenApp && isThisScreenActive

    // Popups currently open
    readonly property bool hasOpenPopups: dockBar.contextMenuOpen || dockBar.appPickerOpen || dockBar.trashMenuOpen || dockBar.downloadsStackOpen || dockBar.windowPickerOpen

    // Detect if any normal window overlaps or touches the dock area on this screen
    readonly property bool windowOverlapsDock: {
        if (!WindowService.windowList || WindowService.windowList.length === 0) {
            return false;
        }

        let scr = window.screen;
        let scrName = (scr && scr.name) ? scr.name : "";
        let scrW = (scr && scr.width > 0) ? scr.width : 1920;
        let scrH = (scr && scr.height > 0) ? scr.height : 1080;
        let scrX = (scr && scr.x !== undefined) ? scr.x : 0;
        let scrY = (scr && scr.y !== undefined) ? scr.y : 0;

        // Dock bounding box in global desktop coordinates
        let dWidth = Math.max(dockBar.capsuleWidth || 300, 300);
        let dHeight = Math.max(dockBar.capsuleHeight || 60, Theme.dockHeight + Theme.dockBottomMargin + 10);

        let dLeft, dRight, dTop, dBottom;
        if (window.dockPosition === "left") {
            dLeft = scrX;
            dRight = scrX + Theme.dockHeight + Theme.dockBottomMargin + 10;
            dTop = scrY + (scrH - dHeight) / 2;
            dBottom = dTop + dHeight;
        } else if (window.dockPosition === "right") {
            dLeft = scrX + scrW - (Theme.dockHeight + Theme.dockBottomMargin + 10);
            dRight = scrX + scrW;
            dTop = scrY + (scrH - dHeight) / 2;
            dBottom = dTop + dHeight;
        } else {
            dLeft = scrX + (scrW - dWidth) / 2;
            dRight = dLeft + dWidth;
            dTop = scrY + scrH - dHeight;
            dBottom = scrY + scrH;
        }

        for (let i = 0; i < WindowService.windowList.length; i++) {
            let w = WindowService.windowList[i];
            if (!w) continue;
            if (w.minimized) continue;
            if (w.onCurrent === false) continue;

            // Never treat quickshell's or plasmashell's own UI as overlapping windows
            let wApp = (w.app || "").toLowerCase();
            if (wApp === "quickshell" || wApp === "plasmashell" || wApp === "org.kde.plasmashell") continue;

            // If window is tied to a specific screen, skip if it belongs to another display
            if (w.screen && scrName && w.screen !== scrName) continue;

            // Maximized window on this screen covers the dock
            if (w.maximized) return true;

            let ww = w.width || 0;
            let wh = w.height || 0;
            if (ww <= 0 || wh <= 0) continue;

            let wx = w.x || 0;
            let wy = w.y || 0;

            if (scrX > 0 && wx < scrX && (wx + ww) <= scrW) wx += scrX;
            if (scrY > 0 && wy < scrY && (wy + wh) <= scrH) wy += scrY;

            let wRight = wx + ww;
            let wBottom = wy + wh;

            // Check AABB intersection
            let intersects = !(wRight <= dLeft || wx >= dRight || wBottom <= dTop || wy >= dBottom);
            if (intersects) return true;
        }

        return false;
    }

    // Auto-hide configuration conditions
    readonly property bool shouldAutoHideFromWindows: SettingsService.dockAutoHideFromWindows && windowOverlapsDock
    readonly property bool shouldAutoHideAlways: SettingsService.dockAutoHideAlways

    // Should the dock be hidden
    readonly property bool isDockHidden: (shouldAutoHideFromWindows || shouldAutoHideAlways) && !hasOpenPopups

    // Reveal state when user dwells near edge
    property bool dockRevealed: false

    // Overall hover state
    readonly property bool isDockHovered: dockStaticHoverHandler.hovered || dockBar.isMouseInside || dockEdgeHoverHandler.hovered

    onIsDockHoveredChanged: {
        if (isDockHovered) {
            dockUnhoverTimer.stop();
            if (window.isDockHidden && !window.dockRevealed) {
                dockDwellTimer.start();
            }
        } else {
            dockDwellTimer.stop();
            if (!hasOpenPopups && window.dockRevealed) {
                dockUnhoverTimer.start();
            }
        }
    }

    onIsDockHiddenChanged: {
        if (!isDockHidden) {
            window.dockRevealed = false;
            dockDwellTimer.stop();
            dockUnhoverTimer.stop();
        }
    }

    // Handle global shortcut / DBus trigger to toggle the app launcher
    Connections {
        target: DockService
        function onToggleAppLauncherRequested() {
            if (window.isThisScreenActive) {
                if (dockBar.appPickerOpen) {
                    dockBar.closeAllPopups();
                } else {
                    window.dockRevealed = true;
                    dockBar.toggleAppPicker();
                }
            }
        }
    }

    // Dwell timer: user holds cursor at screen edge to reveal dock
    Timer {
        id: dockDwellTimer
        interval: 180
        repeat: false
        onTriggered: {
            window.dockRevealed = true;
        }
    }

    // Unhover timer: keeps dock visible briefly after mouse leaves
    Timer {
        id: dockUnhoverTimer
        interval: 800
        repeat: false
        onTriggered: {
            if (!hasOpenPopups && !isDockHovered) {
                window.dockRevealed = false;
            }
        }
    }

    onHasFullscreenAppChanged: {
        if (hasFullscreenApp) {
            dockBar.closeAllPopups();
            window.dockRevealed = false;
        }
    }

    // Whether the dock should currently drop off screen
    readonly property bool shouldDropDock: window.hasFullscreenApp || (window.isDockHidden && !window.dockRevealed)

    // Dedicated drop margin calculation
    readonly property real dropTargetMargin: -Theme.dockHeight - Theme.dockBottomMargin - 24

    // Static hitbox covering the interaction zone
    Item {
        id: dockStaticHitBox
        anchors.bottom: (!window.isVertical) ? parent.bottom : undefined
        anchors.horizontalCenter: (!window.isVertical) ? parent.horizontalCenter : undefined
        anchors.left: (window.dockPosition === "left") ? parent.left : undefined
        anchors.right: (window.dockPosition === "right") ? parent.right : undefined
        anchors.verticalCenter: window.isVertical ? parent.verticalCenter : undefined

        width: window.isVertical ? (Theme.dockHeight + Theme.dockBottomMargin + 48) : Math.round(Math.max((dockBar.capsuleWidth || 0) + 60, Theme.px(420)))
        height: window.isVertical ? Math.round(Math.max((dockBar.capsuleHeight || 0) + 60, Theme.px(420))) : (Theme.dockHeight + Theme.dockBottomMargin + 48)
        visible: !window.hasFullscreenApp && (!window.isDockHidden || window.dockRevealed)

        HoverHandler {
            id: dockStaticHoverHandler
            enabled: dockStaticHitBox.visible
        }
    }

    // Transparent click-through mask
    mask: Region {
        Region {
            item: dockStaticHitBox.visible ? dockStaticHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockBar.contextMenuOpen) ? dockBar.contextMenuHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockBar.appPickerOpen) ? dockBar.appPickerHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockBar.trashMenuOpen) ? dockBar.trashMenuHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockBar.downloadsStackOpen) ? dockBar.downloadsStackHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockBar.windowPickerOpen) ? dockBar.windowPickerHitBox : null
        }
        Region {
            item: (!window.hasFullscreenApp && window.hasOpenPopups) ? fullDismissOverlay : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockEdgeTrigger.visible) ? dockEdgeTrigger : null
        }
    }

    // Edge trigger strip when dock is retracted
    Item {
        id: dockEdgeTrigger
        z: 2
        anchors.bottom: (!window.isVertical) ? parent.bottom : undefined
        anchors.horizontalCenter: (!window.isVertical) ? parent.horizontalCenter : undefined
        anchors.left: (window.dockPosition === "left") ? parent.left : undefined
        anchors.right: (window.dockPosition === "right") ? parent.right : undefined
        anchors.verticalCenter: window.isVertical ? parent.verticalCenter : undefined

        width: window.isVertical ? Math.max(12, Theme.px(12)) : Math.round(Math.max((dockBar.capsuleWidth || 0) + 60, Theme.px(420)))
        height: window.isVertical ? Math.round(Math.max((dockBar.capsuleHeight || 0) + 60, Theme.px(420))) : Math.max(12, Theme.px(12))
        visible: window.isDockHidden && !window.dockRevealed && !window.hasFullscreenApp

        HoverHandler {
            id: dockEdgeHoverHandler
            enabled: dockEdgeTrigger.visible
        }

        TapHandler {
            enabled: dockEdgeTrigger.visible
            onTapped: {
                dockUnhoverTimer.stop();
                dockDwellTimer.stop();
                window.dockRevealed = true;
            }
        }
    }

    // Full dismiss overlay when popup is open
    MouseArea {
        id: fullDismissOverlay
        z: 5
        anchors.fill: parent
        enabled: !window.hasFullscreenApp && window.hasOpenPopups
        onClicked: {
            dockBar.closeAllPopups();
        }
    }

    // Floating Dock Bar Capsule
    DockBar {
        id: dockBar
        z: 10

        anchors.horizontalCenter: (!window.isVertical) ? parent.horizontalCenter : undefined
        anchors.verticalCenter: window.isVertical ? parent.verticalCenter : undefined

        anchors.bottom: (!window.isVertical) ? parent.bottom : undefined
        anchors.bottomMargin: (!window.isVertical) ? (window.shouldDropDock ? window.dropTargetMargin : Theme.dockBottomMargin) : undefined

        anchors.left: (window.dockPosition === "left") ? parent.left : undefined
        anchors.leftMargin: (window.dockPosition === "left") ? (window.shouldDropDock ? window.dropTargetMargin : Theme.dockBottomMargin) : undefined

        anchors.right: (window.dockPosition === "right") ? parent.right : undefined
        anchors.rightMargin: (window.dockPosition === "right") ? (window.shouldDropDock ? window.dropTargetMargin : Theme.dockBottomMargin) : undefined

        // Smooth hide animation when dropped or fullscreen
        opacity: window.hasFullscreenApp ? 0.0 : (window.shouldDropDock ? 0.0 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }
}
