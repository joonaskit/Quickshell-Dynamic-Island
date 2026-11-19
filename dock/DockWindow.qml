import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland
import "dockOverlap.js" as DockOverlap

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

    implicitHeight: window.isVertical ? (window.screen ? window.screen.height : 1080) : 660
    // Beside a vertical dock the launcher can be as wide as its settings column adds
    implicitWidth: window.isVertical ? (660 + Theme.launcherSettingsPaneWidth) : (window.screen ? window.screen.width : 1920)

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
    readonly property bool hasOpenPopups: dockBar.contextMenuOpen || dockBar.appPickerOpen || dockBar.trashMenuOpen || dockBar.launcherMenuOpen || dockBar.downloadsStackOpen || dockBar.windowPickerOpen

    // Whether a window on this screen overlaps or touches the dock (dockOverlap.js)
    readonly property bool windowOverlapsDock: {
        let list = WindowService.windowList;
        if (!list || list.length === 0) return false;
        let scr = window.screen;
        let screenBox = {
            "name": (scr && scr.name) ? scr.name : "",
            "x": (scr && scr.x !== undefined) ? scr.x : 0,
            "y": (scr && scr.y !== undefined) ? scr.y : 0,
            "width": (scr && scr.width > 0) ? scr.width : 1920,
            "height": (scr && scr.height > 0) ? scr.height : 1080
        };
        let edge = Theme.dockHeight + Theme.dockBottomMargin + 10;
        let tall = Math.max(dockBar.capsuleHeight || 60, edge);
        let rect = window.dockPosition === "bottom"
            ? DockOverlap.dockRect(screenBox, "bottom", Math.max(dockBar.capsuleWidth || 300, 300), tall)
            : DockOverlap.dockRect(screenBox, window.dockPosition, tall, edge);
        return DockOverlap.overlaps(list, screenBox, rect);
    }

    // Auto-hide configuration conditions
    readonly property bool shouldAutoHideFromWindows: SettingsService.dockAutoHideFromWindows && windowOverlapsDock
    readonly property bool shouldAutoHideAlways: SettingsService.dockAutoHideAlways

    // Should the dock be hidden
    // niri's overview shows every workspace zoomed out; the dock stays up there so apps can
    // be launched and switched
    readonly property bool isDockHidden: (shouldAutoHideFromWindows || shouldAutoHideAlways) && !hasOpenPopups && !NiriService.overviewOpen

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
        } else if (isDockHovered) {
            // Auto-hide applies again (e.g. a popup just closed) while the pointer
            // is still on the dock: keep it up until the pointer leaves
            window.dockRevealed = true;
        }
    }

    // While the dock is hidden the launcher opens in the middle of the screen
    // (SpotlightWindow) instead of pulling the dock up
    readonly property bool useSpotlight: DockService.spotlightOpen || (SettingsService.launcherSpotlight && window.shouldDropDock && !dockBar.appPickerOpen)

    // Handle global shortcut / DBus trigger to toggle the app launcher
    Connections {
        target: DockService
        function onToggleAppLauncherRequested() {
            if (window.isThisScreenActive) {
                if (window.useSpotlight) {
                    DockService.spotlightRequested(window.screen ? window.screen.name : "", "");
                } else if (dockBar.appPickerOpen) {
                    dockBar.closeAllPopups();
                } else {
                    window.dockRevealed = true;
                    dockBar.toggleAppPicker();
                }
            }
        }

        function onWindowSwitcherRequested() {
            if (window.isThisScreenActive) {
                if (window.useSpotlight) {
                    DockService.spotlightRequested(window.screen ? window.screen.name : "", "Windows");
                } else if (dockBar.appPickerOpen) {
                    dockBar.closeAllPopups();
                } else {
                    window.dockRevealed = true;
                    dockBar.openAppPicker("Windows");
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
        width: window.isVertical ? (Theme.dockHeight + Theme.dockBottomMargin + 48) : Math.round(Math.max((dockBar.capsuleWidth || 0) + 60, Theme.px(420)))
        height: window.isVertical ? Math.round(Math.max((dockBar.capsuleHeight || 0) + 60, Theme.px(420))) : (Theme.dockHeight + Theme.dockBottomMargin + 48)
        x: window.dockPosition === "left" ? 0 : (window.dockPosition === "right" ? (parent.width - width) : Math.round((parent.width - width) / 2))
        y: window.isVertical ? Math.round((parent.height - height) / 2) : (parent.height - height)
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
            item: (!window.hasFullscreenApp && dockBar.launcherMenuOpen) ? dockBar.launcherMenuHitBox : null
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
        width: window.isVertical ? Math.max(12, Theme.px(12)) : Math.round(Math.max((dockBar.capsuleWidth || 0) + 60, Theme.px(420)))
        height: window.isVertical ? Math.round(Math.max((dockBar.capsuleHeight || 0) + 60, Theme.px(420))) : Math.max(12, Theme.px(12))
        x: window.dockPosition === "left" ? 0 : (window.dockPosition === "right" ? (parent.width - width) : Math.round((parent.width - width) / 2))
        y: window.isVertical ? Math.round((parent.height - height) / 2) : (parent.height - height)
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

    // Frosted glass behind the dock and its popups on the light scheme
    WindowBlur {
        target: window
        active: Theme.dockGlass && Theme.blurAvailable
        items: [
            dockBar.capsule,
            dockBar.flyoutBlur(dockBar.contextMenuHitBox, 14),
            dockBar.flyoutBlur(dockBar.appPickerHitBox, Theme.corner(18)),
            dockBar.flyoutBlur(dockBar.trashMenuHitBox, Theme.corner(12)),
            dockBar.flyoutBlur(dockBar.launcherMenuHitBox, Theme.corner(12)),
            dockBar.flyoutBlur(dockBar.downloadsStackHitBox, 14),
            dockBar.flyoutBlur(dockBar.windowPickerHitBox, 14)
        ]
    }

    // Floating Dock Bar Capsule
    // Floating Dock Bar Capsule & Popups
    DockBar {
        id: dockBar
        z: 10
        anchors.fill: parent
        screenName: window.screen ? window.screen.name : ""
        shouldDropDock: window.shouldDropDock

        opacity: window.hasFullscreenApp ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }
}
