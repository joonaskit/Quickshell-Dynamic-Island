import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    // Ample height to allow magnification wave, bouncing icons, tooltips, and app picker popups
    implicitHeight: 520

    // Reserve space at bottom if configured in Theme and not hidden
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
    readonly property bool hasOpenPopups: dockBar.contextMenuOpen || dockBar.appPickerOpen || dockBar.trashMenuOpen

    // Detect if any window overlaps or touches the dock area on this screen
    readonly property bool windowOverlapsDock: {
        // If any window is maximized on the active screen, it covers the dock
        if (WindowService.isMaximized && isThisScreenActive) {
            return true;
        }

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
        let dHeight = Theme.dockHeight + Theme.dockBottomMargin + 10;
        let dLeft = scrX + (scrW - dWidth) / 2;
        let dRight = dLeft + dWidth;
        let dTop = scrY + scrH - dHeight;
        let dBottom = scrY + scrH;

        for (let i = 0; i < WindowService.windowList.length; i++) {
            let w = WindowService.windowList[i];
            if (!w) continue;
            if (w.minimized) continue;
            if (w.onCurrent === false) continue;

            // If window is tied to a specific screen, skip if it belongs to another display
            if (w.screen && scrName && w.screen !== scrName) continue;

            // Maximized window on this screen covers the dock
            if (w.maximized) return true;

            let ww = w.width || 0;
            let wh = w.height || 0;
            if (ww <= 0 || wh <= 0) continue;

            let wx = w.x || 0;
            let wy = w.y || 0;

            // Compensate if coordinates are screen-local instead of global virtual desktop
            if (scrX > 0 && wx < scrX && (wx + ww) <= scrW) {
                wx += scrX;
            }
            if (scrY > 0 && wy < scrY && (wy + wh) <= scrH) {
                wy += scrY;
            }

            let wRight = wx + ww;
            let wBottom = wy + wh;

            // Check AABB intersection with the bottom dock footprint
            let intersects = !(wRight <= dLeft || wx >= dRight || wBottom <= dTop || wy >= dBottom);
            if (intersects) {
                return true;
            }
        }

        return false;
    }

    // Auto-hide configuration conditions
    readonly property bool shouldAutoHideFromWindows: (SettingsService.dockAutoHideFromWindows || Theme.dockAutoHideFromWindows) && windowOverlapsDock
    readonly property bool shouldAutoHideAlways: (SettingsService.dockAutoHideAlways || Theme.dockAutoHideAlways)

    // Should the dock be hidden
    readonly property bool isDockHidden: (shouldAutoHideFromWindows || shouldAutoHideAlways) && !hasOpenPopups

    // Reveal state when user dwells near bottom edge
    property bool dockRevealed: false

    // Overall hover state
    readonly property bool isDockHovered: dockBar.isMouseInside || dockEdgeHoverHandler.hovered

    onIsDockHoveredChanged: {
        if (isDockHovered) {
            dockUnhoverTimer.stop();
        } else {
            dockDwellTimer.stop();
            if (!hasOpenPopups) {
                dockUnhoverTimer.start();
            }
        }
    }

    // Dwell timer: user holds cursor at bottom edge to reveal dock
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
        interval: 750
        repeat: false
        onTriggered: {
            if (!hasOpenPopups) {
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

    // Whether the dock should currently drop down off screen
    readonly property bool shouldDropDock: window.hasFullscreenApp || (window.isDockHidden && !window.dockRevealed)

    // Transparent click-through mask:
    // ONLY the dock capsule (when visible), tooltips, context menus, and dismiss overlay capture clicks!
    mask: Region {
        Region {
            item: (!window.hasFullscreenApp && (!window.isDockHidden || window.dockRevealed)) ? dockBar.hitBox : null
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
            item: (!window.hasFullscreenApp && (dockBar.contextMenuOpen || dockBar.appPickerOpen || dockBar.trashMenuOpen)) ? fullDismissOverlay : null
        }
        Region {
            item: (!window.hasFullscreenApp && dockEdgeTrigger.visible) ? dockEdgeTrigger : null
        }
    }

    // Edge trigger strip at the bottom of the screen when dock is retracted
    Item {
        id: dockEdgeTrigger
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.max(10, Theme.px(10))
        width: Math.max((dockBar.capsuleWidth || 300) + 60, Theme.px(360))
        visible: window.isDockHidden && !window.dockRevealed && !window.hasFullscreenApp

        HoverHandler {
            id: dockEdgeHoverHandler
            enabled: dockEdgeTrigger.visible
            onHoveredChanged: {
                if (hovered) {
                    dockUnhoverTimer.stop();
                    dockDwellTimer.start();
                } else {
                    dockDwellTimer.stop();
                }
            }
        }

        TapHandler {
            onTapped: {
                dockUnhoverTimer.stop();
                dockDwellTimer.stop();
                window.dockRevealed = true;
            }
        }
    }

    // Ambient edge glow when the retracted dock is approached by the cursor
    HiddenElementGlow {
        id: dockGlow
        z: 10
        atBottom: true
        targetX: Math.round((parent.width - targetWidth) / 2)
        targetWidth: dockBar.capsuleWidth > 0 ? dockBar.capsuleWidth : Theme.px(400)
        active: window.isDockHidden && !window.dockRevealed && !window.hasFullscreenApp && dockEdgeHoverHandler.hovered
        accentColor: Theme.accentBlue
    }

    // Full dismiss overlay when popup is open
    MouseArea {
        id: fullDismissOverlay
        anchors.fill: parent
        enabled: !window.hasFullscreenApp && (dockBar.contextMenuOpen || dockBar.appPickerOpen || dockBar.trashMenuOpen)
        onClicked: {
            dockBar.closeAllPopups();
        }
    }

    // Floating Dock Bar Capsule
    DockBar {
        id: dockBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.shouldDropDock ? (-height - Theme.dockBottomMargin - 20) : Theme.dockBottomMargin

        // Smooth hide animation when dropped or fullscreen
        opacity: window.hasFullscreenApp ? 0.0 : (window.shouldDropDock ? 0.0 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }
}
