import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property alias hitBox: dockHitBox
    property alias contextMenuHitBox: contextMenu
    property alias appPickerHitBox: appPicker
    property alias trashMenuHitBox: trashMenu

    property alias contextMenuOpen: contextMenu.isOpen
    property alias appPickerOpen: appPicker.isOpen
    property alias trashMenuOpen: trashMenu.isOpen

    readonly property real capsuleWidth: dockCapsule.width
    readonly property real capsuleX: dockCapsule.x

    implicitHeight: (appPickerOpen || contextMenuOpen || trashMenuOpen) ? 500 : Theme.dockHeight
    implicitWidth: Math.max(dockCapsule.width, appPickerOpen ? (appPicker.width + 20) : 0)
    width: implicitWidth
    height: implicitHeight

    // Mouse tracking for magnification wave
    property real currentMouseX: -9999
    property bool isMouseInside: false

    // Drag and drop state for reordering pinned apps
    property int draggedIndex: -1
    property int dragTargetIndex: -1
    property real dragOffset: 0
    readonly property bool isDraggingPinned: draggedIndex >= 0

    function closeAllPopups() {
        contextMenu.isOpen = false;
        appPicker.isOpen = false;
        trashMenu.isOpen = false;
    }

    function toggleAppPicker() {
        contextMenu.isOpen = false;
        trashMenu.isOpen = false;
        appPicker.isOpen = !appPicker.isOpen;
    }

    // Extended hitbox covering capsule, icon magnification overshoot, and indicator dots
    Item {
        id: dockHitBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: Theme.dockHeight + 24
        width: dockCapsule.width + 16

        // MouseArea over the entire dock to calculate fluid magnification wave
        MouseArea {
            id: dockMouseTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onEntered: {
                root.isMouseInside = true;
            }

            onExited: {
                root.isMouseInside = false;
                root.currentMouseX = -9999;
            }

            onPositionChanged: function(mouse) {
                if (root.isDraggingPinned) return;
                let mapped = mapToItem(contentRow, mouse.x, mouse.y);
                root.currentMouseX = mapped.x;
            }
        }
    }

    // Dock capsule background
    Rectangle {
        id: dockCapsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: Theme.dockHeight
        width: contentRow.implicitWidth + 24
        radius: Theme.dockRadius
        color: Theme.dockBackground
        border.color: Theme.dockBorder
        border.width: Theme.dockShowBorder ? 1 : 0

        // Top subtle highlight edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            radius: Theme.dockRadius
            color: Qt.rgba(1, 1, 1, 0.22)
            visible: Theme.dockShowBorder && !Theme.dockTransparent
        }

        // Horizontal Row containing all dock items
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 2

            // Launchpad / App Picker Icon
            Item {
                id: launchpadItem
                width: Theme.dockIconSize + 8
                height: Theme.dockHeight

                property real dockScale: {
                    if (root.isDraggingPinned || !root.isMouseInside) return 1.0;
                    let center = launchpadItem.x + launchpadItem.width / 2;
                    let dist = Math.abs((root.currentMouseX - 12) - center);
                    if (dist < 80) {
                        return 1.0 + (Theme.dockScaleHover - 1.0) * Math.cos((dist / 80) * (Math.PI / 2));
                    }
                    return 1.0;
                }

                Behavior on dockScale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: launchpadBg
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: Theme.dockIconSize
                    height: Theme.dockIconSize
                    radius: 12
                    transformOrigin: Item.Bottom
                    scale: launchpadItem.dockScale

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2c2c2e" }
                        GradientStop { position: 1.0; color: "#1c1c1e" }
                    }
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1

                    // 9-dot Launchpad icon grid
                    Grid {
                        anchors.centerIn: parent
                        columns: 3
                        rows: 3
                        spacing: 4

                        Repeater {
                            model: 9
                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: "#ffffff"
                            }
                        }
                    }
                }

                // Tooltip
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: launchpadBg.top
                    anchors.bottomMargin: 14 + (launchpadItem.dockScale - 1.0) * Theme.dockIconSize
                    width: launchpadTipBg.width
                    height: launchpadTipBg.height
                    opacity: (launchpadMouse.containsMouse && launchpadItem.dockScale > 1.1) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

                    Rectangle {
                        id: launchpadTipBg
                        width: launchpadTipText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: "#1c1c1e"
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1

                        Text {
                            id: launchpadTipText
                            anchors.centerIn: parent
                            text: "Launchpad"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }
                }

                MouseArea {
                    id: launchpadMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onEntered: { root.isMouseInside = true; }
                    onPositionChanged: function(mouse) {
                        if (root.isDraggingPinned) return;
                        let p = launchpadMouse.mapToItem(contentRow, mouse.x, mouse.y);
                        root.isMouseInside = true;
                        root.currentMouseX = p.x;
                    }

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            appPicker.isOpen = !appPicker.isOpen;
                            contextMenu.isOpen = false;
                        } else {
                            appPicker.isOpen = !appPicker.isOpen;
                            contextMenu.isOpen = false;
                        }
                    }
                }
            }

            // Divider between Launchpad and Pinned apps
            Rectangle {
                width: 1
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            // Pinned Applications Repeater
            Repeater {
                id: pinnedRepeater
                model: DockService.pinnedApps

                delegate: DockItem {
                    id: pinnedItem
                    appData: modelData
                    isDraggable: true
                    itemIndex: index

                    readonly property bool isBeingDragged: root.draggedIndex === index
                    readonly property real itemStep: pinnedItem.width + contentRow.spacing

                    readonly property real displacement: {
                        if (root.draggedIndex < 0) return 0;
                        if (isBeingDragged) return root.dragOffset;

                        let fromIdx = root.draggedIndex;
                        let toIdx = root.dragTargetIndex;
                        if (toIdx > fromIdx) {
                            if (index > fromIdx && index <= toIdx) {
                                return -itemStep;
                            }
                        } else if (toIdx < fromIdx) {
                            if (index < fromIdx && index >= toIdx) {
                                return itemStep;
                            }
                        }
                        return 0;
                    }

                    transform: Translate {
                        x: pinnedItem.displacement

                        Behavior on x {
                            enabled: !pinnedItem.isBeingDragged
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    z: isBeingDragged ? 100 : 1
                    opacity: isBeingDragged ? 0.92 : 1.0

                    dockScale: {
                        if (root.isDraggingPinned) {
                            return isBeingDragged ? 1.15 : 1.0;
                        }
                        if (!root.isMouseInside) return 1.0;
                        let itemCenterX = pinnedItem.x + pinnedItem.width / 2;
                        let dist = Math.abs(root.currentMouseX - itemCenterX);
                        if (dist < 85) {
                            return 1.0 + (Theme.dockScaleHover - 1.0) * Math.cos((dist / 85) * (Math.PI / 2));
                        }
                        return 1.0;
                    }

                    onMouseMoved: function(cx) {
                        if (!root.isDraggingPinned) {
                            root.isMouseInside = true;
                            root.currentMouseX = cx;
                        }
                    }

                    onDragStarted: function(idx, startX) {
                        root.closeAllPopups();
                        root.draggedIndex = idx;
                        root.dragTargetIndex = idx;
                        root.dragOffset = 0;
                    }

                    onDragMoved: function(idx, dx, currentX) {
                        root.dragOffset = dx;
                        let shift = Math.round(dx / pinnedItem.itemStep);
                        let maxIdx = DockService.pinnedApps.length - 1;
                        let newTarget = Math.max(0, Math.min(maxIdx, idx + shift));
                        root.dragTargetIndex = newTarget;
                    }

                    onDragFinished: function(idx) {
                        let fromIdx = root.draggedIndex;
                        let toIdx = root.dragTargetIndex;
                        root.draggedIndex = -1;
                        root.dragTargetIndex = -1;
                        root.dragOffset = 0;
                        if (fromIdx >= 0 && toIdx >= 0 && fromIdx !== toIdx) {
                            DockService.reorderPinnedApps(fromIdx, toIdx);
                        }
                    }

                    onRequestContextMenu: function(app, x, y) {
                        contextMenu.appData = app;
                        let mapped = pinnedItem.mapToItem(root, pinnedItem.width / 2, 0);
                        contextMenu.targetX = mapped.x;
                        contextMenu.targetY = dockCapsule.y;
                        contextMenu.isOpen = true;
                        appPicker.isOpen = false;
                    }
                }
            }

            // Divider between Pinned and Running Unpinned apps
            Rectangle {
                visible: DockService.runningUnpinnedApps.length > 0
                width: 1
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            // Running Unpinned Applications Repeater
            Repeater {
                id: unpinnedRepeater
                model: DockService.runningUnpinnedApps

                delegate: DockItem {
                    id: unpinnedItem
                    appData: modelData

                    dockScale: {
                        if (root.isDraggingPinned || !root.isMouseInside) return 1.0;
                        let itemCenterX = unpinnedItem.x + unpinnedItem.width / 2;
                        let dist = Math.abs(root.currentMouseX - itemCenterX);
                        if (dist < 85) {
                            return 1.0 + (Theme.dockScaleHover - 1.0) * Math.cos((dist / 85) * (Math.PI / 2));
                        }
                        return 1.0;
                    }

                    onMouseMoved: function(cx) {
                        if (!root.isDraggingPinned) {
                            root.isMouseInside = true;
                            root.currentMouseX = cx;
                        }
                    }

                    onRequestContextMenu: function(app, x, y) {
                        contextMenu.appData = app;
                        let mapped = unpinnedItem.mapToItem(root, unpinnedItem.width / 2, 0);
                        contextMenu.targetX = mapped.x;
                        contextMenu.targetY = dockCapsule.y;
                        contextMenu.isOpen = true;
                        appPicker.isOpen = false;
                    }
                }
            }

            // Divider before Trash
            Rectangle {
                width: 1
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            // Trash Icon
            Item {
                id: trashItem
                width: Theme.dockIconSize + 8
                height: Theme.dockHeight

                property real dockScale: {
                    if (root.isDraggingPinned || !root.isMouseInside) return 1.0;
                    let center = trashItem.x + trashItem.width / 2;
                    let dist = Math.abs(root.currentMouseX - center);
                    if (dist < 85) {
                        return 1.0 + (Theme.dockScaleHover - 1.0) * Math.cos((dist / 85) * (Math.PI / 2));
                    }
                    return 1.0;
                }

                Behavior on dockScale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                Item {
                    id: trashIconContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: Theme.dockIconSize
                    height: Theme.dockIconSize
                    transformOrigin: Item.Bottom
                    scale: trashItem.dockScale

                    // System Trash icon
                    Image {
                        anchors.fill: parent
                        source: DockService.trashCount > 0 ? DockService.resolveIcon("user-trash-full") : DockService.resolveIcon("user-trash")
                        sourceSize.width: 128
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true

                        // Fallback vector icon
                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: "#2c2c2e"
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            visible: parent.status !== Image.Ready

                            SvgIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 20
                                color: Theme.textSecondary
                            }
                        }
                    }
                }

                // Tooltip
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: trashIconContainer.top
                    anchors.bottomMargin: 14 + (trashItem.dockScale - 1.0) * Theme.dockIconSize
                    width: trashTipBg.width
                    height: trashTipBg.height
                    opacity: (trashMouse.containsMouse && trashItem.dockScale > 1.1) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

                    Rectangle {
                        id: trashTipBg
                        width: trashTipText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: "#1c1c1e"
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1

                        Text {
                            id: trashTipText
                            anchors.centerIn: parent
                            text: DockService.trashCount > 0 ? ("Trash (" + DockService.trashCount + ")") : "Trash"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }
                }

                MouseArea {
                    id: trashMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onEntered: { root.isMouseInside = true; }
                    onPositionChanged: function(mouse) {
                        if (root.isDraggingPinned) return;
                        let p = trashMouse.mapToItem(contentRow, mouse.x, mouse.y);
                        root.isMouseInside = true;
                        root.currentMouseX = p.x;
                    }

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            let mapped = trashItem.mapToItem(root, trashItem.width / 2, 0);
                            trashMenu.targetX = mapped.x;
                            trashMenu.targetY = dockCapsule.y;
                            trashMenu.isOpen = true;
                            contextMenu.isOpen = false;
                            appPicker.isOpen = false;
                        } else {
                            DockService.openTrash();
                        }
                    }
                }
            }
        }
    }

    // Context Menu for Applications
    DockContextMenu {
        id: contextMenu
        onClosed: {
            appData = null;
        }
    }

    // Trash Context Menu
    Item {
        id: trashMenu
        property bool isOpen: false
        property real targetX: 0
        property real targetY: 0

        visible: opacity > 0.001
        opacity: isOpen ? 1.0 : 0.0
        scale: isOpen ? 1.0 : 0.92
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing; easing.overshoot: Theme.animEntranceOvershoot }
        }

        width: 150
        height: trashCol.implicitHeight + 16
        x: Math.max(8, Math.min(root.width - width - 8, targetX - width / 2))
        y: targetY - height - 10

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#1c1c1e"
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
        }

        Column {
            id: trashCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Rectangle {
                width: parent.width
                height: 28
                radius: 6
                color: openTrashMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open Trash"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: openTrashMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        DockService.openTrash();
                        trashMenu.isOpen = false;
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 28
                radius: 6
                color: emptyTrashMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.25) : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Empty Trash"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: emptyTrashMouse.containsMouse ? Theme.accentRed : Theme.textPrimary
                }

                MouseArea {
                    id: emptyTrashMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        DockService.emptyTrash();
                        trashMenu.isOpen = false;
                    }
                }
            }
        }
    }

    // App Picker Popup
    DockAppPicker {
        id: appPicker
        anchors.bottom: dockCapsule.top
        anchors.bottomMargin: 14
        anchors.horizontalCenter: dockCapsule.horizontalCenter
    }

    // Dismiss overlay to close popups on outside click
    MouseArea {
        id: dismissOverlay
        anchors.fill: parent
        z: -1
        enabled: contextMenu.isOpen || appPicker.isOpen || trashMenu.isOpen
        onClicked: {
            root.closeAllPopups();
            trashMenu.isOpen = false;
        }
    }
}
