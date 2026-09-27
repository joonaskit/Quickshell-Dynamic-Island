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

    // Reserve space at bottom if configured in Theme
    exclusiveZone: (Theme.dockReserveSpace && !window.hasFullscreenApp) ? (Theme.dockHeight + Theme.dockBottomMargin) : 0
    aboveWindows: true

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "apple-dock"
    WlrLayershell.keyboardFocus: dockBar.appPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Check if this screen is active or primary
    readonly property bool isThisScreenActive: {
        if (!WindowService.activeScreen) return true;
        if (!window.screen || !window.screen.name) return true;
        return WindowService.activeScreen === window.screen.name;
    }

    // Auto-hide when a fullscreen window (game, video, presentation) is active
    readonly property bool hasFullscreenApp: Theme.dockAutoHideOnFullscreen && WindowService.hasFullscreenApp && isThisScreenActive

    onHasFullscreenAppChanged: {
        if (hasFullscreenApp) {
            dockBar.closeAllPopups();
        }
    }

    // Transparent click-through mask:
    // ONLY the dock capsule, tooltips, context menus, and dismiss overlay capture clicks!
    mask: Region {
        Region {
            item: (!window.hasFullscreenApp) ? dockBar.hitBox : null
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
        anchors.bottomMargin: window.hasFullscreenApp ? (-height - 20) : Theme.dockBottomMargin

        // Smooth hide animation when fullscreen
        opacity: window.hasFullscreenApp ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }
}
