import ".."
import QtQuick
import Quickshell
import Quickshell.Wayland

// The launcher in the middle of the screen, dropping out of the island pill. Used
// instead of the dock's launcher while the dock is hidden (see useSpotlight in DockWindow).
// Created once per screen; DockService.spotlightRequested names the screen.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    visible: mapped

    // Unmapped a moment after the launcher has shrunk away, so the last frame is
    // empty. KWin plays its close effect on that frame, and with the launcher still
    // in it the effect showed it moving again after it reached the pill.
    property bool mapped: false
    Timer {
        id: unmapTimer
        interval: 120
        onTriggered: window.mapped = false
    }

    // Above fullscreen windows too, where the dock is hidden as well
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-spotlight"
    WlrLayershell.keyboardFocus: picker.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: DockService
        function onSpotlightRequested(screenName, category) {
            if (screenName !== "" && window.screen && screenName !== window.screen.name) return;
            if (picker.isOpen) {
                picker.close();
            } else {
                picker.pendingCategory = category;
                picker.isOpen = true;
            }
        }
    }

    // A click outside the launcher closes it
    MouseArea {
        anchors.fill: parent
        onClicked: picker.close()
    }

    // The island pill (see IslandPill), which the launcher drops out of. It sits
    // at the very top as a bar while a window is maximized.
    readonly property bool pillIsBar: WindowService.isMaximized && Theme.morphToTopBarWhenMaximized && !WindowService.hasFullscreenApp

    DockAppPicker {
        id: picker
        centered: true
        originY: window.pillIsBar ? 0 : Theme.topMargin
        originWidth: Theme.compactWidthClock
        originHeight: window.pillIsBar ? Theme.topBarHeight : Theme.compactHeight
        originRadius: window.pillIsBar ? 0 : Theme.compactRadius
        onIsOpenChanged: {
            DockService.spotlightOpen = isOpen;
            if (isOpen) {
                unmapTimer.stop();
                window.mapped = true;
            }
        }
        onVisibleChanged: if (!visible && !isOpen) unmapTimer.restart()
    }
}
