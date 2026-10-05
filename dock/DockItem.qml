import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var appData: null
    property real dockScale: 1.0
    property bool isHovered: false
    property bool isDraggable: false
    property int itemIndex: -1
    property bool isDragging: false
    property real launchBounceHeight: 0
    property real clickBounceHeight: 0
    readonly property real bounceHeight: launchBounceHeight + clickBounceHeight
    property real pressScale: 1.0

    readonly property bool isVertical: Theme.dockPosition === "left" || Theme.dockPosition === "right"
    readonly property string dockPosition: Theme.dockPosition

    Behavior on pressScale {
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    signal requestContextMenu(var app, real x, real y)
    signal requestWindowPicker(var app, real x, real y)
    signal requestCloseWindowPicker()
    signal mouseMoved(real contentCoord)
    signal mouseExited()
    signal dragStarted(int index, real startPos)
    signal dragMoved(int index, real delta, real currentPos)
    signal dragFinished(int index)

    readonly property var stateObj: (appData && DockService.runningStateMap[appData.id]) ? DockService.runningStateMap[appData.id] : ({ running: false, focused: false, count: 0 })
    readonly property bool isRunning: stateObj.running
    readonly property bool isFocused: stateObj.focused
    readonly property int windowCount: stateObj.count
    readonly property int unreadNotifCount: (root.appData && NotificationService.notifications) ? NotificationService.getUnreadCountForApp(root.appData.id, root.appData.name) : 0

    width: isVertical ? Theme.dockHeight : (Theme.dockIconSize + 8)
    height: isVertical ? (Theme.dockIconSize + 8) : Theme.dockHeight

    // Smooth scaling behavior
    Behavior on dockScale {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // Snappy bounce animation on click
    SequentialAnimation {
        id: clickBounceAnim
        alwaysRunToEnd: true

        NumberAnimation {
            target: root
            property: "clickBounceHeight"
            to: 12
            duration: 100
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "clickBounceHeight"
            to: 0
            duration: 150
            easing.type: Easing.OutBounce
        }
    }

    // Launch bounce animation
    SequentialAnimation {
        id: bounceAnim
        loops: 3
        NumberAnimation { target: root; property: "launchBounceHeight"; to: 22; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "launchBounceHeight"; to: 0; duration: 180; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "launchBounceHeight"; to: 12; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "launchBounceHeight"; to: 0; duration: 140; easing.type: Easing.InQuad }
    }

    // Stop bounce if window appears
    onIsRunningChanged: {
        if (isRunning && bounceAnim.running) {
            bounceAnim.stop();
            launchBounceHeight = 0;
        }
    }

    // Multi-window hover picker trigger
    onIsHoveredChanged: {
        if (isHovered) {
            if (windowCount > 1 && !isDragging) {
                hoverPickerTimer.restart();
            }
        } else {
            hoverPickerTimer.stop();
            root.requestCloseWindowPicker();
        }
    }

    Timer {
        id: hoverPickerTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (root.isHovered && root.windowCount > 1 && !root.isDragging) {
                let mapped = root.mapToItem(null, root.width / 2, root.height / 2);
                root.requestWindowPicker(root.appData, mapped.x, mapped.y);
            }
        }
    }

    Timer {
        id: wheelResetTimer
        interval: 120
        repeat: false
        onTriggered: root.pressScale = 1.0
    }

    // Main Icon Container that scales and bounces
    Item {
        id: iconContainer
        width: Theme.dockIconSize
        height: Theme.dockIconSize

        x: root.isVertical ? (Math.round((parent.width - width) / 2) + (root.dockPosition === "left" ? root.bounceHeight : -root.bounceHeight)) : Math.round((parent.width - width) / 2)
        y: root.isVertical ? Math.round((parent.height - height) / 2) : (Math.round((parent.height - height) / 2) - root.bounceHeight)

        transformOrigin: Item.Center
        scale: root.dockScale * root.pressScale

        // Application icon image
        Image {
            id: appIcon
            anchors.fill: parent
            source: appData ? DockService.resolveIcon(appData.icon) : ""
            sourceSize.width: 128
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true

            // Subtle drop shadow under icon
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.85
                height: parent.height * 0.85
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.25)
                z: -1
                visible: appIcon.status === Image.Ready
            }
        }

        // Fallback squircle icon if image fails to load
        Rectangle {
            anchors.fill: parent
            radius: 11
            visible: appIcon.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3a3a3c" }
                GradientStop { position: 1.0; color: "#242426" }
            }
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: appData ? (appData.name ? appData.name.charAt(0).toUpperCase() : "?") : "?"
                font.family: Theme.fontDisplay
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#ffffff"
            }
        }

        // Unread Notification Badge
        Rectangle {
            id: notifBadge
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -4
            anchors.rightMargin: -4
            z: 10
            height: 18
            width: Math.max(18, badgeText.implicitWidth + 8)
            radius: 9
            color: Theme.accentRed
            border.color: "#1c1c1e"
            border.width: 1.5
            visible: opacity > 0.01
            opacity: root.unreadNotifCount > 0 ? 1.0 : 0.0
            scale: root.unreadNotifCount > 0 ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutBack } }

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.unreadNotifCount > 99 ? "99+" : String(root.unreadNotifCount)
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#ffffff"
            }
        }
    }

    // Active Window Glow Halo
    Rectangle {
        id: pipGlow
        z: 1

        width: root.isVertical ? 8 : (root.isFocused ? 22 : 0)
        height: root.isVertical ? (root.isFocused ? 22 : 0) : 8
        radius: 4
        color: Qt.rgba(10/255, 132/255, 255/255, 0.45)
        opacity: (root.isRunning && root.isFocused) ? 1.0 : 0.0

        x: root.isVertical ? (root.dockPosition === "left" ? Math.round(4 + (4 - width) / 2) : Math.round(parent.width - 4 - 4 + (4 - width) / 2)) : Math.round((parent.width - width) / 2)
        y: root.isVertical ? Math.round((parent.height - height) / 2) : Math.round(parent.height - 4 - 4 + (4 - height) / 2)

        Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }
        Behavior on width { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic } }
    }

    // Running indicator dot / active pill
    Rectangle {
        id: runningDot
        z: 2

        width: root.isVertical ? 4 : (root.isFocused ? 14 : (root.windowCount > 1 ? 8 : 4))
        height: root.isVertical ? (root.isFocused ? 14 : (root.windowCount > 1 ? 8 : 4)) : 4
        radius: 2
        color: root.isFocused ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.75)
        opacity: root.isRunning ? 1.0 : 0.0

        x: root.isVertical ? (root.dockPosition === "left" ? 4 : (parent.width - width - 4)) : Math.round((parent.width - width) / 2)
        y: root.isVertical ? Math.round((parent.height - height) / 2) : (parent.height - height - 4)

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }
    }

    // Tooltip floating above or beside icon (shown only when 1 or 0 windows)
    Item {
        id: tooltipContainer

        width: tooltipBg.width
        height: tooltipBg.height

        x: root.isVertical ? (root.dockPosition === "left" ? (iconContainer.x + iconContainer.width + 14 + (root.dockScale - 1.0) * Theme.dockIconSize) : (iconContainer.x - width - 14 - (root.dockScale - 1.0) * Theme.dockIconSize)) : Math.round((parent.width - width) / 2)
        y: root.isVertical ? Math.round((parent.height - height) / 2) : (iconContainer.y - height - 14 - (root.dockScale - 1.0) * Theme.dockIconSize)

        opacity: (!root.isDragging && root.isHovered && root.dockScale > 1.1 && root.windowCount <= 1) ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationTooltip }
        }

        Rectangle {
            id: tooltipBg
            width: tooltipText.implicitWidth + 16
            height: 24
            radius: 6
            color: "#1c1c1e"
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: appData ? appData.name : ""
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.textPrimary
            }
        }
    }

    // Mouse area for click, drag, scroll, and hover
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (root.isDraggable && root.isDragging) ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real pressStartCoord: 0
        property bool hasDragged: false

        onEntered: {
            root.isHovered = true;
        }

        onExited: {
            root.isHovered = false;
            root.mouseExited();
        }

        // Scroll wheel to cycle through open windows!
        onWheel: function(wheel) {
            if (!root.appData || !root.isRunning) return;
            let wins = DockService.findToplevels(root.appData);
            if (wins.length <= 1) return;

            let activeIdx = -1;
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].activated) {
                    activeIdx = i;
                    break;
                }
            }

            let nextIdx = 0;
            if (wheel.angleDelta.y < 0) {
                // Scroll down: cycle next window
                nextIdx = (activeIdx + 1) % wins.length;
            } else {
                // Scroll up: cycle previous window
                nextIdx = (activeIdx - 1 + wins.length) % wins.length;
            }

            let nw = wins[nextIdx];
            if (nw.isKWin) {
                WindowService.activateWindow(nw.id);
            } else if (nw.raw) {
                if (nw.raw.minimized) nw.raw.minimized = false;
                nw.raw.activate();
            }

            root.pressScale = 0.92;
            wheelResetTimer.restart();
        }

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                let mapped = root.mapToItem(root.parent, mouse.x, mouse.y);
                pressStartCoord = root.isVertical ? mapped.y : mapped.x;
                hasDragged = false;
                root.pressScale = 0.88;
            }
        }

        onPositionChanged: function(mouse) {
            let mapped = root.mapToItem(root.parent, mouse.x, mouse.y);
            let currentCoord = root.isVertical ? mapped.y : mapped.x;

            if ((mouse.buttons & Qt.LeftButton) && root.isDraggable) {
                let delta = currentCoord - pressStartCoord;
                if (!hasDragged && Math.abs(delta) > 6) {
                    hasDragged = true;
                    root.pressScale = 1.0;
                    root.isDragging = true;
                    root.dragStarted(root.itemIndex, pressStartCoord);
                }
                if (hasDragged) {
                    root.dragMoved(root.itemIndex, delta, currentCoord);
                    return;
                }
            }
            root.mouseMoved(currentCoord);
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.pressScale = 1.0;
                if (hasDragged) {
                    hasDragged = false;
                    root.isDragging = false;
                    root.dragFinished(root.itemIndex);
                    return;
                }
            }
        }

        onCanceled: {
            root.pressScale = 1.0;
            if (hasDragged) {
                hasDragged = false;
                root.isDragging = false;
                root.dragFinished(root.itemIndex);
            }
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                let mapPos = root.mapToItem(null, root.width / 2, root.height / 2);
                root.requestContextMenu(root.appData, mapPos.x, mapPos.y);
            } else if (!hasDragged && !root.isDragging) {
                root.pressScale = 1.0;
                clickBounceAnim.restart();
                if (!root.isRunning) {
                    bounceAnim.restart();
                }
                if (root.appData) {
                    DockService.activateOrLaunch(root.appData);
                }
            }
        }
    }
}
