import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Item {
    id: root

    property bool isExpanded: false
    property bool isSettingsOpen: false
    property bool isTopBarMode: false
    property bool hasFullscreenApp: false
    property bool isHovered: compactClickArea.containsMouse && !root.isTopBarMode && !root.hasFullscreenApp
    property date currentDate: clock.date

    // System services
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Find first active media player
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool hasMediaPlaying: activePlayer !== null && activePlayer.isPlaying

    // Hitbox reference for window click-through mask
    property alias hitBox: pillBody

    readonly property bool isAlertingNotification: NotificationService.isAlerting && NotificationService.latestNotification !== null

    // Compact base width (stable across hover and expand)
    readonly property real compactWidth: {
        if (root.isAlertingNotification) return Theme.px(310);
        return (root.hasMediaPlaying && Theme.showMediaWhenPlaying)
            ? Theme.compactWidthMedia
            : Theme.compactWidthClock;
    }

    readonly property real settingsWidth: Theme.px(540)

    // Target dimensions based on state
    readonly property real targetWidth: {
        if (root.isSettingsOpen) {
            return root.settingsWidth;
        }
        if (root.isExpanded) {
            return Theme.expandedWidth;
        }
        if (root.isAlertingNotification) {
            return Theme.px(310) + (root.isHovered ? Theme.px(8) : 0);
        }
        if (root.hasMediaPlaying && Theme.showMediaWhenPlaying) {
            return Theme.compactWidthMedia + (root.isHovered ? Theme.px(10) : 0);
        }
        return Theme.compactWidthClock + (root.isHovered ? Theme.px(8) : 0);
    }

    readonly property real targetHeight: {
        if (root.isSettingsOpen) {
            return settingsView.implicitHeight;
        }
        if (root.isExpanded) {
            return expandedView.implicitHeight;
        }
        if (root.isTopBarMode) {
            return Theme.topBarHeight + 1;
        }
        return Theme.compactHeight;
    }

    // Corner radii: morphs to 0 in top-bar mode, rounded when floating
    readonly property real targetTopRadius: {
        if (root.isTopBarMode && !root.isExpanded && !root.isSettingsOpen) return 0;
        return (root.isExpanded || root.isSettingsOpen) ? Theme.expandedRadius : Theme.compactRadius;
    }

    // Bottom radii: rounds to 0 in top-bar mode, expandedRadius when expanded, compactRadius when compact
    readonly property real targetBottomRadius: {
        if (root.isTopBarMode && !root.isExpanded && !root.isSettingsOpen) return 0;
        return (root.isExpanded || root.isSettingsOpen) ? Theme.expandedRadius : Theme.compactRadius;
    }

    implicitWidth: pillBody.width
    implicitHeight: pillBody.height

    function toggle() {
        if (root.isSettingsOpen) {
            root.collapse();
        } else {
            root.isExpanded = !root.isExpanded;
        }
    }

    function expand() {
        root.isExpanded = true;
        root.isSettingsOpen = false;
    }

    function collapse() {
        root.isExpanded = false;
        root.isSettingsOpen = false;
    }

    function openSettings() {
        root.isSettingsOpen = true;
    }

    function closeSettings() {
        root.isSettingsOpen = false;
    }

    // Inactivity auto-collapse timer (disabled when settings is open or timeout is 0)
    Timer {
        id: autoCollapseTimer
        interval: Theme.autoCollapseTimeout > 0 ? Theme.autoCollapseTimeout : 6000
        running: root.isExpanded && !root.isSettingsOpen && !pillHoverHandler.hovered && Theme.autoCollapseTimeout > 0
        repeat: false
        onTriggered: {
            root.collapse();
        }
    }

    // Layered Soft Ambient Shadow
    Rectangle {
        id: ambientGlow
        anchors.horizontalCenter: pillBody.horizontalCenter
        anchors.centerIn: pillBody
        width: pillBody.width + Theme.px(12)
        height: pillBody.height + Theme.px(10)

        topLeftRadius: root.targetTopRadius + Theme.px(4)
        topRightRadius: root.targetTopRadius + Theme.px(4)
        bottomLeftRadius: root.targetBottomRadius + Theme.px(4)
        bottomRightRadius: root.targetBottomRadius + Theme.px(4)

        color: Theme.islandShadow
        opacity: (root.isTopBarMode && !root.isExpanded && !root.isSettingsOpen) ? 0.0 : ((root.isExpanded || root.isSettingsOpen) ? 0.65 : 0.45)
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Island Body
    Rectangle {
        id: pillBody
        anchors.top: parent.top
        anchors.topMargin: (root.isTopBarMode && (root.isExpanded || root.isSettingsOpen)) ? -1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetWidth
        height: root.targetHeight + ((root.isTopBarMode && (root.isExpanded || root.isSettingsOpen)) ? 1 : 0)

        topLeftRadius: root.targetTopRadius
        topRightRadius: root.targetTopRadius
        bottomLeftRadius: root.targetBottomRadius
        bottomRightRadius: root.targetBottomRadius

        color: Theme.islandBackground
        clip: true

        HoverHandler {
            id: pillHoverHandler
            enabled: !root.isTopBarMode && !root.hasFullscreenApp
        }

        border.color: root.isHovered ? Theme.islandBorderHover : Theme.islandBorder
        border.width: root.isTopBarMode ? 0 : 1

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Theme.animEasing
                easing.overshoot: Theme.animOvershoot
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: (root.isExpanded || root.isSettingsOpen) ? Theme.animEasing : Easing.OutCubic
                easing.overshoot: (root.isExpanded || root.isSettingsOpen) ? Theme.animOvershoot : 1.0
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

        Behavior on border.color {
            ColorAnimation { duration: 180 }
        }

        // Compact Clock View
        CompactClockView {
            id: compactClockView
            anchors.centerIn: parent
            currentTime: root.currentDate
            use24Hour: Theme.use24Hour
            isHovered: root.isHovered
            opacity: (!root.isExpanded && !root.isSettingsOpen && !root.isAlertingNotification && (!root.hasMediaPlaying || !Theme.showMediaWhenPlaying)) ? 1.0 : 0.0
            scale: opacity > 0.5 ? 1.0 : 0.94
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        }

        // Compact Media View
        CompactMediaView {
            id: compactMediaView
            anchors.centerIn: parent
            currentTime: root.currentDate
            player: root.activePlayer
            opacity: (!root.isExpanded && !root.isSettingsOpen && !root.isAlertingNotification && root.hasMediaPlaying && Theme.showMediaWhenPlaying) ? 1.0 : 0.0
            scale: opacity > 0.5 ? 1.0 : 0.94
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        }

        // Compact Notification Alert View (pops open when a notification arrives)
        CompactNotificationAlertView {
            id: compactNotificationView
            anchors.centerIn: parent
            opacity: (!root.isExpanded && !root.isSettingsOpen && root.isAlertingNotification) ? 1.0 : 0.0
            scale: opacity > 0.5 ? 1.0 : 0.94
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        }

        // Click-to-expand MouseArea: active ONLY when compact!
        MouseArea {
            id: compactClickArea
            anchors.fill: parent
            enabled: !root.isExpanded && !root.isSettingsOpen
            hoverEnabled: !root.isExpanded && !root.isSettingsOpen && !root.isTopBarMode && !root.hasFullscreenApp
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (!root.isExpanded && !root.isSettingsOpen) {
                    root.expand();
                }
            }
        }

        // Click-to-collapse MouseArea: active when expanded
        MouseArea {
            id: expandedClickArea
            anchors.fill: parent
            enabled: root.isExpanded && !root.isSettingsOpen
            cursorShape: Qt.ArrowCursor

            onClicked: {
                root.collapse();
            }
        }

        // Expanded Card View
        ExpandedView {
            id: expandedView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            currentTime: root.currentDate
            player: root.activePlayer
            displayBattery: UPower.displayDevice

            opacity: (root.isExpanded && !root.isSettingsOpen) ? 1.0 : 0.0
            scale: opacity > 0.5 ? 1.0 : 0.97
            visible: opacity > 0.01

            onRequestCollapse: {
                root.collapse();
            }

            onRequestOpenSettings: {
                root.openSettings();
            }

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        }

        // Settings Card View
        SettingsView {
            id: settingsView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            opacity: root.isSettingsOpen ? 1.0 : 0.0
            scale: opacity > 0.5 ? 1.0 : 0.97
            visible: opacity > 0.01

            onRequestBack: {
                root.isSettingsOpen = false;
            }

            onRequestClose: {
                root.collapse();
            }

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        }
    }
}
