import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var appData: null
    property real dockScale: 1.0
    property bool isHovered: false
    property real bounceOffset: 0
    property bool isDraggable: false
    property int itemIndex: -1
    property bool isDragging: false
    property real jiggleAngle: 0
    property real pressScale: 1.0

    signal requestContextMenu(var app, real x, real y)
    signal mouseMoved(real contentRowX)
    signal mouseExited()
    signal dragStarted(int index, real startX)
    signal dragMoved(int index, real deltaX, real currentX)
    signal dragFinished(int index)

    readonly property var stateObj: (appData && DockService.runningStateMap[appData.id]) ? DockService.runningStateMap[appData.id] : ({ running: false, focused: false, count: 0 })
    readonly property bool isRunning: stateObj.running
    readonly property bool isFocused: stateObj.focused
    readonly property int windowCount: stateObj.count

    width: Theme.dockIconSize + 8
    height: Theme.dockHeight

    // Smooth scaling behavior
    Behavior on dockScale {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    // Interactive press squish & tactile jiggle animation on click
    SequentialAnimation {
        id: jiggleAnim
        alwaysRunToEnd: true

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "jiggleAngle"; to: -7; duration: 45; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "jiggleAngle"; to: 6; duration: 45; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "jiggleAngle"; to: -4; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "jiggleAngle"; to: 3; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "jiggleAngle"; to: -1.5; duration: 35; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "jiggleAngle"; to: 0; duration: 30; easing.type: Easing.OutQuad }
            }
            SequentialAnimation {
                NumberAnimation { target: root; property: "pressScale"; to: 0.88; duration: 40; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "pressScale"; to: 1.08; duration: 80; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                NumberAnimation { target: root; property: "pressScale"; to: 0.97; duration: 50; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "pressScale"; to: 1.0; duration: 65; easing.type: Easing.OutQuad }
            }
        }
    }

    // Launch bounce animation
    SequentialAnimation {
        id: bounceAnim
        loops: 3
        NumberAnimation { target: root; property: "bounceOffset"; to: -22; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounceOffset"; to: 0; duration: 180; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "bounceOffset"; to: -12; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounceOffset"; to: 0; duration: 140; easing.type: Easing.InQuad }
    }

    // Stop bounce if window appears
    onIsRunningChanged: {
        if (isRunning && bounceAnim.running) {
            bounceAnim.stop();
            bounceOffset = 0;
        }
    }

    // Main Icon Container that scales and bounces
    Item {
        id: iconContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: Theme.dockIconSize
        height: Theme.dockIconSize

        transformOrigin: Item.Bottom
        scale: root.dockScale * root.pressScale
        rotation: root.jiggleAngle
        y: root.bounceOffset

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
    }

    // Running indicator dot directly underneath the icon
    Rectangle {
        id: runningDot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: root.isFocused ? 10 : 4
        height: 4
        radius: 2
        color: root.isFocused ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.75)
        opacity: root.isRunning ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }
    }

    // Tooltip floating above icon
    Item {
        id: tooltipContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: iconContainer.top
        anchors.bottomMargin: 14 + (root.dockScale - 1.0) * Theme.dockIconSize
        width: tooltipBg.width
        height: tooltipBg.height
        opacity: (!root.isDragging && root.isHovered && root.dockScale > 1.1) ? 1.0 : 0.0
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

    // Mouse area for click, drag, and hover
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (root.isDraggable && root.isDragging) ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real pressStartContentX: 0
        property real pressStartContentY: 0
        property bool hasDragged: false

        onEntered: {
            root.isHovered = true;
        }

        onExited: {
            root.isHovered = false;
            root.mouseExited();
        }

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                let mapped = root.mapToItem(root.parent, mouse.x, mouse.y);
                pressStartContentX = mapped.x;
                pressStartContentY = mapped.y;
                hasDragged = false;
                root.pressScale = 0.90;
            }
        }

        onPositionChanged: function(mouse) {
            let mapped = root.mapToItem(root.parent, mouse.x, mouse.y);
            if ((mouse.buttons & Qt.LeftButton) && root.isDraggable) {
                let dx = mapped.x - pressStartContentX;
                let dy = mapped.y - pressStartContentY;
                if (!hasDragged && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
                    hasDragged = true;
                    root.pressScale = 1.0;
                    root.isDragging = true;
                    root.dragStarted(root.itemIndex, pressStartContentX);
                }
                if (hasDragged) {
                    root.dragMoved(root.itemIndex, dx, mapped.x);
                    return;
                }
            }
            root.mouseMoved(mapped.x);
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (hasDragged) {
                    hasDragged = false;
                    root.isDragging = false;
                    root.dragFinished(root.itemIndex);
                    root.pressScale = 1.0;
                    return;
                }
                if (!jiggleAnim.running) {
                    root.pressScale = 1.0;
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
                let mapPos = root.mapToItem(null, root.width / 2, 0);
                root.requestContextMenu(root.appData, mapPos.x, mapPos.y);
            } else if (!hasDragged && !root.isDragging) {
                jiggleAnim.restart();
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
