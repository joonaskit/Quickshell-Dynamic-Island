import ".."
import QtQuick

Item {
    id: root

    property alias hitBox: dockHitBox
    property alias contextMenuHitBox: contextMenu
    property alias appPickerHitBox: appPicker
    property alias trashMenuHitBox: trashMenu
    property alias launcherMenuHitBox: launcherMenu
    property alias downloadsStackHitBox: downloadsStack
    property alias windowPickerHitBox: windowPicker

    property alias contextMenuOpen: contextMenu.isOpen
    property alias appPickerOpen: appPicker.isOpen
    property alias trashMenuOpen: trashMenu.isOpen
    property alias launcherMenuOpen: launcherMenu.isOpen
    property alias downloadsStackOpen: downloadsStack.isOpen
    property alias windowPickerOpen: windowPicker.isOpen

    readonly property bool isVertical: Theme.dockPosition === "left" || Theme.dockPosition === "right"
    readonly property string dockPosition: Theme.dockPosition

    readonly property real capsuleWidth: dockCapsule.width
    readonly property real capsuleHeight: dockCapsule.height
    readonly property real capsuleX: dockCapsule.x
    readonly property real capsuleY: dockCapsule.y

    readonly property bool hasOpenPopups: appPickerOpen || contextMenuOpen || trashMenuOpen || launcherMenuOpen || downloadsStackOpen || windowPickerOpen

    property bool shouldDropDock: false

    readonly property real dockContentLength: {
        let slotSize = Theme.dockIconSize + 8;
        let pinnedCount = (DockService.pinnedApps && DockService.pinnedApps.length) ? DockService.pinnedApps.length : 0;
        let unpinnedCount = (DockService.runningUnpinnedApps && DockService.runningUnpinnedApps.length) ? DockService.runningUnpinnedApps.length : 0;
        let slots = 3 + pinnedCount + unpinnedCount;
        let dividers = 2 + (unpinnedCount > 0 ? 1 : 0);
        let totalItems = slots + dividers;
        let spacing = 2;
        return (slots * slotSize) + (dividers * 1) + (Math.max(0, totalItems - 1) * spacing);
    }

    onDockContentLengthChanged: {
        Qt.callLater(contentContainer.forceLayout);
    }

    Connections {
        target: DockService
        function onPinnedAppsChanged() {
            Qt.callLater(contentContainer.forceLayout);
        }
        function onRunningUnpinnedAppsChanged() {
            Qt.callLater(contentContainer.forceLayout);
        }
    }

    implicitWidth: isVertical ? (hasOpenPopups ? 660 : (dockCapsule.width + Theme.dockBottomMargin)) : Math.max(dockCapsule.width, appPickerOpen ? (appPicker.finalWidth + 64) : 0)
    implicitHeight: isVertical ? Math.max(dockCapsule.height, appPickerOpen ? (appPicker.finalHeight + 64) : 0) : (hasOpenPopups ? 660 : (dockCapsule.height + Theme.dockBottomMargin))

    // Mouse tracking for fluid magnification wave
    property real currentMouseX: -9999
    property real currentMouseY: -9999
    property bool isMouseInside: false

    // Drag and drop state for reordering pinned apps
    property int draggedIndex: -1
    property int dragTargetIndex: -1
    property real dragOffset: 0
    readonly property bool isDraggingPinned: draggedIndex >= 0

    function calcDockScale(itemCenter) {
        if (root.isDraggingPinned || !root.isMouseInside) return 1.0;
        let mouseCoord = root.isVertical ? root.currentMouseY : root.currentMouseX;
        let dist = Math.abs(mouseCoord - itemCenter);
        if (dist < 85) {
            return 1.0 + (Theme.dockScaleHover - 1.0) * Math.cos((dist / 85) * (Math.PI / 2));
        }
        return 1.0;
    }

    function closeAllPopups(except) {
        if (except !== contextMenu) contextMenu.isOpen = false;
        appPicker.isOpen = false;
        trashMenu.isOpen = false;
        launcherMenu.isOpen = false;
        downloadsStack.isOpen = false;
        windowPicker.isOpen = false;
    }

    function toggleAppPicker() {
        let wasOpen = appPicker.isOpen;
        closeAllPopups();
        appPicker.isOpen = !wasOpen;
    }

    function toggleLauncherMenu() {
        let wasOpen = launcherMenu.isOpen;
        closeAllPopups();
        launcherMenu.isOpen = !wasOpen;
    }

    function toggleTrashMenu() {
        let wasOpen = trashMenu.isOpen;
        closeAllPopups();
        trashMenu.isOpen = !wasOpen;
    }

    function isContextMenuOpenFor(app) {
        return contextMenu.isOpen && !!app && !!contextMenu.appData && contextMenu.appData.id === app.id;
    }

    // Open the context menu for an icon, or close it if it is already open for that icon
    function toggleContextMenu(app, item) {
        if (root.isContextMenuOpenFor(app)) {
            contextMenu.isOpen = false;
            contextMenu.closed();
            return;
        }
        // An open menu stays open and morphs to the new icon
        closeAllPopups(contextMenu);
        contextClearTimer.stop();
        contextMenu.appData = app;
        let mapped = item.mapToItem(root, item.width / 2, item.height / 2);
        contextMenu.targetX = mapped.x;
        contextMenu.targetY = mapped.y;
        contextMenu.isOpen = true;
    }

    function openAppPicker(category) {
        closeAllPopups();
        appPicker.pendingCategory = category || "";
        appPicker.isOpen = true;
    }

    function toggleDownloadsStack() {
        let wasOpen = downloadsStack.isOpen;
        closeAllPopups();
        if (!wasOpen) {
            let mapped = downloadsItem.mapToItem(root, downloadsItem.width / 2, downloadsItem.height / 2);
            downloadsStack.targetX = mapped.x;
            downloadsStack.targetY = root.isVertical ? mapped.y : dockCapsule.y;
            downloadsStack.targetY = mapped.y;
            downloadsStack.isOpen = true;
            DownloadsService.refresh();
        }
    }

    // Extended hitbox covering capsule, icon magnification overshoot, and indicator dots
    Item {
        id: dockHitBox

        anchors.horizontalCenter: root.isVertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined

        anchors.bottom: (!root.isVertical) ? parent.bottom : undefined
        anchors.left: (root.dockPosition === "left") ? parent.left : undefined // qmllint disable Quick.anchor-combinations
        anchors.right: (root.dockPosition === "right") ? parent.right : undefined

        width: root.isVertical ? (dockCapsule.width + Theme.dockBottomMargin + 16) : (dockCapsule.width + 16)
        height: root.isVertical ? (dockCapsule.height + 16) : (dockCapsule.height + Theme.dockBottomMargin + 16)

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
                root.currentMouseY = -9999;
            }

            onPositionChanged: function(mouse) {
                if (root.isDraggingPinned) return;
                let mapped = mapToItem(contentContainer, mouse.x, mouse.y);
                root.currentMouseX = mapped.x;
                root.currentMouseY = mapped.y;
            }
        }
    }

    // With fractional display scaling, a whole-number position usually falls
    // between two physical pixels. The dock edge that popups attach to is snapped
    // to the pixel grid: the dock and a popup share that edge, and if both draw
    // it half-covered the wallpaper shows through as a thin line.
    readonly property real pixelRatio: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    function snapToPixel(v) {
        return Math.round(v * pixelRatio) / pixelRatio;
    }
    readonly property real dockThickness: snapToPixel(Theme.dockHeight)
    // Gap between the dock and its screen edge, adjusted so that the opposite
    // (popup-facing) edge of the dock lands on a physical pixel
    readonly property real dockEdgeMargin: {
        if (root.dockPosition === "left") return snapToPixel(Theme.dockBottomMargin);
        let extent = root.isVertical ? root.width : root.height;
        return extent - dockThickness - snapToPixel(extent - Theme.dockBottomMargin - dockThickness);
    }

    // The launcher and the trash menu continue an end of the dock in a straight
    // line, so the dock straightens its corner under them as they open. Start is
    // the launcher's end (left, or top for a vertical dock).
    readonly property real startCornerRadius: Theme.dockRadius * (1 - Math.max(0, Math.min(1, Math.max(appPicker.openProgress, launcherMenu.openProgress) * 3)))
    readonly property real endCornerRadius: Theme.dockRadius * (1 - Math.max(0, Math.min(1, trashGeo.progress * 3)))

    // Dock capsule background
    Rectangle {
        id: dockCapsule

        anchors.horizontalCenter: root.isVertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined

        anchors.bottom: (!root.isVertical) ? parent.bottom : undefined
        anchors.bottomMargin: (!root.isVertical) ? root.dockEdgeMargin : 0

        anchors.left: (root.dockPosition === "left") ? parent.left : undefined // qmllint disable Quick.anchor-combinations
        anchors.leftMargin: (root.dockPosition === "left") ? root.dockEdgeMargin : 0

        anchors.right: (root.dockPosition === "right") ? parent.right : undefined
        anchors.rightMargin: (root.dockPosition === "right") ? root.dockEdgeMargin : 0

        width: root.isVertical ? root.dockThickness : (root.dockContentLength + 32)
        height: root.isVertical ? (root.dockContentLength + 32) : root.dockThickness
        radius: Theme.dockRadius
        // The two corners on the popup-facing edge: bottom dock top-left / top-right,
        // left dock top-right / bottom-right, right dock top-left / bottom-left
        topLeftRadius: root.dockPosition === "left" ? radius : root.startCornerRadius
        topRightRadius: root.dockPosition === "bottom" ? root.endCornerRadius : (root.dockPosition === "left" ? root.startCornerRadius : radius)
        bottomRightRadius: root.dockPosition === "left" ? root.endCornerRadius : radius
        bottomLeftRadius: root.dockPosition === "right" ? root.endCornerRadius : radius
        color: Theme.dockBackground
        border.color: Theme.dockBorder
        border.width: Theme.dockShowBorder ? 1 : 0

        Behavior on width {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }

        transform: Translate {
            x: {
                if (!root.isVertical || !root.shouldDropDock) return 0;
                return (root.dockPosition === "left") ? (-dockCapsule.width - Theme.dockBottomMargin - 24) : (dockCapsule.width + Theme.dockBottomMargin + 24);
            }
            y: {
                if (root.isVertical || !root.shouldDropDock) return 0;
                return dockCapsule.height + Theme.dockBottomMargin + 24;
            }

            Behavior on x {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

        // Frosted glass inner specular reflection & depth gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomRightRadius: parent.bottomRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            visible: Theme.dockTransparent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.03) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.14) }
            }
        }

        // Content Container (Grid: acts as Row when horizontal, Column when vertical)
        Grid {
            id: contentContainer
            anchors.centerIn: parent
            columns: root.isVertical ? 1 : 999
            spacing: 2
            width: root.isVertical ? Theme.dockHeight : root.dockContentLength
            height: root.isVertical ? root.dockContentLength : Theme.dockHeight

            Component.onCompleted: Qt.callLater(contentContainer.forceLayout)
            onWidthChanged: Qt.callLater(contentContainer.forceLayout)
            onHeightChanged: Qt.callLater(contentContainer.forceLayout)

            // Launchpad / App Picker Icon
            Item {
                id: launchpadItem
                width: root.isVertical ? Theme.dockHeight : (Theme.dockIconSize + 8)
                height: root.isVertical ? (Theme.dockIconSize + 8) : Theme.dockHeight

                property real bounceHeight: 0
                property real pressScale: 1.0

                Behavior on pressScale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                SequentialAnimation {
                    id: launchpadBounceAnim
                    alwaysRunToEnd: true
                    NumberAnimation { target: launchpadItem; property: "bounceHeight"; to: 12; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: launchpadItem; property: "bounceHeight"; to: 0; duration: 150; easing.type: Easing.OutBounce }
                }

                property real dockScale: {
                    let center = root.isVertical ? (launchpadItem.y + launchpadItem.height / 2) : (launchpadItem.x + launchpadItem.width / 2);
                    return root.calcDockScale(center);
                }

                Behavior on dockScale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: launchpadBg
                    width: Theme.dockIconSize
                    height: Theme.dockIconSize
                    radius: 12

                    x: root.isVertical ? (Math.round((parent.width - width) / 2) + (root.dockPosition === "left" ? launchpadItem.bounceHeight : -launchpadItem.bounceHeight)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (Math.round((parent.height - height) / 2) - launchpadItem.bounceHeight)

                    transformOrigin: Item.Center
                    scale: launchpadItem.dockScale * launchpadItem.pressScale

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.cardBackgroundHover }
                        GradientStop { position: 1.0; color: Theme.cardBackground }
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
                                color: Theme.textPrimary
                            }
                        }
                    }
                }

                // Tooltip
                Item {
                    width: launchpadTipBg.width
                    height: launchpadTipBg.height

                    x: root.isVertical ? (root.dockPosition === "left" ? (launchpadBg.x + launchpadBg.width + 14 + (launchpadItem.dockScale - 1.0) * Theme.dockIconSize) : (launchpadBg.x - width - 14 - (launchpadItem.dockScale - 1.0) * Theme.dockIconSize)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (launchpadBg.y - height - 14 - (launchpadItem.dockScale - 1.0) * Theme.dockIconSize)

                    opacity: (launchpadMouse.containsMouse && launchpadItem.dockScale > 1.1) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

                    Rectangle {
                        id: launchpadTipBg
                        width: launchpadTipText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: Theme.cardBackground
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
                        let p = launchpadMouse.mapToItem(contentContainer, mouse.x, mouse.y);
                        root.isMouseInside = true;
                        root.currentMouseX = p.x;
                        root.currentMouseY = p.y;
                    }

                    onPressed: {
                        launchpadItem.pressScale = 0.88;
                    }
                    onReleased: {
                        launchpadItem.pressScale = 1.0;
                    }
                    onCanceled: {
                        launchpadItem.pressScale = 1.0;
                    }

                    onClicked: function(mouse) {
                        launchpadItem.pressScale = 1.0;
                        launchpadBounceAnim.restart();
                        if (mouse.button === Qt.RightButton) root.toggleLauncherMenu();
                        else root.toggleAppPicker();
                    }
                }
            }

            // Divider between Launchpad and Pinned apps
            Item {
                width: root.isVertical ? Theme.dockHeight : 1
                height: root.isVertical ? 1 : Theme.dockHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.isVertical ? 28 : 1
                    height: root.isVertical ? 1 : 28
                    color: Qt.rgba(1, 1, 1, 0.15)
                }
            }

            // Pinned Applications Repeater
            Repeater {
                id: pinnedRepeater
                model: DockService.pinnedApps
                onCountChanged: Qt.callLater(contentContainer.forceLayout)
                onModelChanged: Qt.callLater(contentContainer.forceLayout)

                delegate: DockItem {
                    id: pinnedItem
                    appData: modelData
                    isDraggable: true
                    itemIndex: index

                    readonly property bool isBeingDragged: root.draggedIndex === index
                    readonly property real itemStep: (root.isVertical ? pinnedItem.height : pinnedItem.width) + contentContainer.spacing

                    readonly property real displacement: {
                        if (root.draggedIndex < 0) return 0;
                        if (isBeingDragged) return root.dragOffset;

                        let fromIdx = root.draggedIndex;
                        let toIdx = root.dragTargetIndex;
                        if (toIdx > fromIdx) {
                            if (index > fromIdx && index <= toIdx) return -itemStep;
                        } else if (toIdx < fromIdx) {
                            if (index < fromIdx && index >= toIdx) return itemStep;
                        }
                        return 0;
                    }

                    transform: Translate {
                        x: root.isVertical ? 0 : pinnedItem.displacement
                        y: root.isVertical ? pinnedItem.displacement : 0

                        Behavior on x {
                            enabled: !pinnedItem.isBeingDragged && !root.isVertical
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: !pinnedItem.isBeingDragged && root.isVertical
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    z: isBeingDragged ? 100 : 1
                    opacity: isBeingDragged ? 0.92 : 1.0

                    dockScale: {
                        if (root.isDraggingPinned) return isBeingDragged ? 1.15 : 1.0;
                        let center = root.isVertical ? (pinnedItem.y + pinnedItem.height / 2) : (pinnedItem.x + pinnedItem.width / 2);
                        return root.calcDockScale(center);
                    }

                    onMouseMoved: function(coord) {
                        if (!root.isDraggingPinned) {
                            root.isMouseInside = true;
                            if (root.isVertical) root.currentMouseY = coord;
                            else root.currentMouseX = coord;
                        }
                    }

                    onDragStarted: function(idx, startPos) {
                        root.closeAllPopups();
                        root.draggedIndex = idx;
                        root.dragTargetIndex = idx;
                        root.dragOffset = 0;
                    }

                    onDragMoved: function(idx, delta, currentPos) {
                        root.dragOffset = delta;
                        let shift = Math.round(delta / pinnedItem.itemStep);
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

                    contextMenuOpen: root.isContextMenuOpenFor(appData)
                    onRequestContextMenu: function(app, x, y) {
                        root.toggleContextMenu(app, pinnedItem);
                    }

                    onRequestWindowPicker: function(app, x, y) {
                        if (!contextMenu.isOpen && !appPicker.isOpen && !downloadsStack.isOpen) {
                            windowPickerCloseTimer.stop();
                            windowClearTimer.stop();
                            windowPicker.appData = app;
                            let mapped = pinnedItem.mapToItem(root, pinnedItem.width / 2, pinnedItem.height / 2);
                            windowPicker.targetX = mapped.x;
                            windowPicker.targetY = mapped.y;
                            windowPicker.isOpen = true;
                        }
                    }

                    onRequestCloseWindowPicker: function() {
                        windowPickerCloseTimer.restart();
                    }
                }
            }

            // Divider between Pinned and Running Unpinned apps
            Item {
                visible: DockService.runningUnpinnedApps.length > 0
                width: visible ? (root.isVertical ? Theme.dockHeight : 1) : 0
                height: visible ? (root.isVertical ? 1 : Theme.dockHeight) : 0
                onVisibleChanged: Qt.callLater(contentContainer.forceLayout)

                Rectangle {
                    anchors.centerIn: parent
                    width: root.isVertical ? 28 : 1
                    height: root.isVertical ? 1 : 28
                    color: Qt.rgba(1, 1, 1, 0.15)
                }
            }

            // Running Unpinned Applications Repeater
            Repeater {
                id: unpinnedRepeater
                model: DockService.runningUnpinnedApps
                onCountChanged: Qt.callLater(contentContainer.forceLayout)
                onModelChanged: Qt.callLater(contentContainer.forceLayout)

                delegate: DockItem {
                    id: unpinnedItem
                    appData: modelData

                    dockScale: {
                        if (root.isDraggingPinned) return 1.0;
                        let center = root.isVertical ? (unpinnedItem.y + unpinnedItem.height / 2) : (unpinnedItem.x + unpinnedItem.width / 2);
                        return root.calcDockScale(center);
                    }

                    onMouseMoved: function(coord) {
                        if (!root.isDraggingPinned) {
                            root.isMouseInside = true;
                            if (root.isVertical) root.currentMouseY = coord;
                            else root.currentMouseX = coord;
                        }
                    }

                    contextMenuOpen: root.isContextMenuOpenFor(appData)
                    onRequestContextMenu: function(app, x, y) {
                        root.toggleContextMenu(app, unpinnedItem);
                    }

                    onRequestWindowPicker: function(app, x, y) {
                        if (!contextMenu.isOpen && !appPicker.isOpen && !downloadsStack.isOpen) {
                            windowPickerCloseTimer.stop();
                            windowClearTimer.stop();
                            windowPicker.appData = app;
                            let mapped = unpinnedItem.mapToItem(root, unpinnedItem.width / 2, unpinnedItem.height / 2);
                            windowPicker.targetX = mapped.x;
                            windowPicker.targetY = mapped.y;
                            windowPicker.isOpen = true;
                        }
                    }

                    onRequestCloseWindowPicker: function() {
                        windowPickerCloseTimer.restart();
                    }
                }
            }

            // Divider before Downloads & Trash
            Item {
                width: root.isVertical ? Theme.dockHeight : 1
                height: root.isVertical ? 1 : Theme.dockHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.isVertical ? 28 : 1
                    height: root.isVertical ? 1 : 28
                    color: Qt.rgba(1, 1, 1, 0.15)
                }
            }

            // Downloads / Recent Files Stack Icon
            Item {
                id: downloadsItem
                width: root.isVertical ? Theme.dockHeight : (Theme.dockIconSize + 8)
                height: root.isVertical ? (Theme.dockIconSize + 8) : Theme.dockHeight

                property real bounceHeight: 0
                property real pressScale: 1.0

                Behavior on pressScale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                SequentialAnimation {
                    id: downloadsBounceAnim
                    alwaysRunToEnd: true
                    NumberAnimation { target: downloadsItem; property: "bounceHeight"; to: 12; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: downloadsItem; property: "bounceHeight"; to: 0; duration: 150; easing.type: Easing.OutBounce }
                }

                property real dockScale: {
                    let center = root.isVertical ? (downloadsItem.y + downloadsItem.height / 2) : (downloadsItem.x + downloadsItem.width / 2);
                    return root.calcDockScale(center);
                }

                Behavior on dockScale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: downloadsIconContainer
                    width: Theme.dockIconSize
                    height: Theme.dockIconSize
                    radius: 12

                    x: root.isVertical ? (Math.round((parent.width - width) / 2) + (root.dockPosition === "left" ? downloadsItem.bounceHeight : -downloadsItem.bounceHeight)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (Math.round((parent.height - height) / 2) - downloadsItem.bounceHeight)

                    transformOrigin: Item.Center
                    scale: downloadsItem.dockScale * downloadsItem.pressScale

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.cardBackgroundHover }
                        GradientStop { position: 1.0; color: Theme.cardBackground }
                    }
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1

                    // Downloads Folder Stack Icon
                    SvgIcon {
                        anchors.centerIn: parent
                        name: "folder"
                        size: 22
                        color: Theme.accentBlue
                    }
                }

                // Tooltip
                Item {
                    width: downloadsTipBg.width
                    height: downloadsTipBg.height

                    x: root.isVertical ? (root.dockPosition === "left" ? (downloadsIconContainer.x + downloadsIconContainer.width + 14 + (downloadsItem.dockScale - 1.0) * Theme.dockIconSize) : (downloadsIconContainer.x - width - 14 - (downloadsItem.dockScale - 1.0) * Theme.dockIconSize)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (downloadsIconContainer.y - height - 14 - (downloadsItem.dockScale - 1.0) * Theme.dockIconSize)

                    opacity: (downloadsMouse.containsMouse && downloadsItem.dockScale > 1.1) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

                    Rectangle {
                        id: downloadsTipBg
                        width: downloadsTipText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: Theme.cardBackground
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1

                        Text {
                            id: downloadsTipText
                            anchors.centerIn: parent
                            text: "Downloads Stack"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }
                }

                MouseArea {
                    id: downloadsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onEntered: { root.isMouseInside = true; }
                    onPositionChanged: function(mouse) {
                        if (root.isDraggingPinned) return;
                        let p = downloadsMouse.mapToItem(contentContainer, mouse.x, mouse.y);
                        root.isMouseInside = true;
                        root.currentMouseX = p.x;
                        root.currentMouseY = p.y;
                    }

                    onPressed: {
                        downloadsItem.pressScale = 0.88;
                    }
                    onReleased: {
                        downloadsItem.pressScale = 1.0;
                    }
                    onCanceled: {
                        downloadsItem.pressScale = 1.0;
                    }

                    onClicked: function(mouse) {
                        downloadsItem.pressScale = 1.0;
                        downloadsBounceAnim.restart();
                        root.toggleDownloadsStack();
                    }
                }
            }

            // Trash Icon
            Item {
                id: trashItem
                width: root.isVertical ? Theme.dockHeight : (Theme.dockIconSize + 8)
                height: root.isVertical ? (Theme.dockIconSize + 8) : Theme.dockHeight

                property real bounceHeight: 0
                property real pressScale: 1.0

                Behavior on pressScale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                SequentialAnimation {
                    id: trashBounceAnim
                    alwaysRunToEnd: true
                    NumberAnimation { target: trashItem; property: "bounceHeight"; to: 12; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: trashItem; property: "bounceHeight"; to: 0; duration: 150; easing.type: Easing.OutBounce }
                }

                property real dockScale: {
                    let center = root.isVertical ? (trashItem.y + trashItem.height / 2) : (trashItem.x + trashItem.width / 2);
                    return root.calcDockScale(center);
                }

                Behavior on dockScale {
                    NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic }
                }

                Item {
                    id: trashIconContainer
                    width: Theme.dockIconSize
                    height: Theme.dockIconSize

                    x: root.isVertical ? (Math.round((parent.width - width) / 2) + (root.dockPosition === "left" ? trashItem.bounceHeight : -trashItem.bounceHeight)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (Math.round((parent.height - height) / 2) - trashItem.bounceHeight)

                    transformOrigin: Item.Center
                    scale: trashItem.dockScale * trashItem.pressScale

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
                            color: Theme.cardBackgroundHover
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
                    width: trashTipBg.width
                    height: trashTipBg.height

                    x: root.isVertical ? (root.dockPosition === "left" ? (trashIconContainer.x + trashIconContainer.width + 14 + (trashItem.dockScale - 1.0) * Theme.dockIconSize) : (trashIconContainer.x - width - 14 - (trashItem.dockScale - 1.0) * Theme.dockIconSize)) : Math.round((parent.width - width) / 2)
                    y: root.isVertical ? Math.round((parent.height - height) / 2) : (trashIconContainer.y - height - 14 - (trashItem.dockScale - 1.0) * Theme.dockIconSize)

                    opacity: (trashMouse.containsMouse && trashItem.dockScale > 1.1) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }

                    Rectangle {
                        id: trashTipBg
                        width: trashTipText.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: Theme.cardBackground
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
                        let p = trashMouse.mapToItem(contentContainer, mouse.x, mouse.y);
                        root.isMouseInside = true;
                        root.currentMouseX = p.x;
                        root.currentMouseY = p.y;
                    }

                    onPressed: {
                        trashItem.pressScale = 0.88;
                    }
                    onReleased: {
                        trashItem.pressScale = 1.0;
                    }
                    onCanceled: {
                        trashItem.pressScale = 1.0;
                    }

                    onClicked: function(mouse) {
                        trashItem.pressScale = 1.0;
                        trashBounceAnim.restart();
                        if (mouse.button === Qt.RightButton) {
                            root.toggleTrashMenu();
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
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: dockCapsule.x
        dockCapsuleY: dockCapsule.y
        dockCapsuleWidth: dockCapsule.width
        dockCapsuleHeight: dockCapsule.height
        // Clear after the close animation so the menu doesn't empty while shrinking
        onClosed: contextClearTimer.restart()
    }

    Timer {
        id: contextClearTimer
        interval: Theme.animDurationFast + 60
        onTriggered: {
            if (!contextMenu.isOpen) contextMenu.appData = null;
        }
    }

    // Multi-Window Preview / Picker Popup
    DockWindowPicker {
        id: windowPicker
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: dockCapsule.x
        dockCapsuleY: dockCapsule.y
        dockCapsuleWidth: dockCapsule.width
        dockCapsuleHeight: dockCapsule.height
        // Clear after the close animation so the list doesn't empty while shrinking
        onClosed: windowClearTimer.restart()
    }

    // Leaving the icon doesn't close the list straight away, so the pointer can
    // travel onto it; it stays open while hovered.
    Timer {
        id: windowPickerCloseTimer
        interval: 260
        onTriggered: {
            if (!windowPicker.hovered) windowPicker.isOpen = false;
        }
    }

    Connections {
        target: windowPicker
        function onHoveredChanged() {
            if (windowPicker.hovered) windowPickerCloseTimer.stop();
            else if (windowPicker.isOpen) windowPickerCloseTimer.restart();
        }
    }

    Timer {
        id: windowClearTimer
        interval: Theme.animDurationFast + 60
        onTriggered: {
            if (!windowPicker.isOpen) windowPicker.appData = null;
        }
    }

    // Downloads Stack Popup
    DockDownloadsStack {
        id: downloadsStack
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: dockCapsule.x
        dockCapsuleY: dockCapsule.y
        dockCapsuleWidth: dockCapsule.width
        dockCapsuleHeight: dockCapsule.height
    }

    // Trash Context Menu
    Item {
        id: trashMenu
        property bool isOpen: false

        // Mirrors the launcher: grows out of the corner by the trash icon, with its
        // side continuing the end of the dock in one line
        DockFlyoutGeometry {
            id: trashGeo
            open: trashMenu.isOpen
            isVertical: root.isVertical
            dockPosition: root.dockPosition
            dockCapsuleX: dockCapsule.x
            dockCapsuleY: dockCapsule.y
            dockCapsuleWidth: dockCapsule.width
            dockCapsuleHeight: dockCapsule.height
            align: "end"
            finalWidth: 150
            finalHeight: trashCol.implicitHeight + 16
            parentWidth: root.width
            parentHeight: root.height
        }

        visible: trashGeo.progress > 0.001
        opacity: Math.min(1.0, trashGeo.progress * 4)

        x: trashGeo.x
        y: trashGeo.y
        width: trashGeo.width
        height: trashGeo.height

        DockFlyoutBackground {
            isVertical: root.isVertical
            dockPosition: root.dockPosition
            filletSize: trashGeo.filletSize
            cornerRadius: 12
            dockCornerRadius: root.endCornerRadius
            endFlush: trashGeo.endFlush
            farFillet: trashGeo.farFillet
            farOverhang: trashGeo.farOverhang
        }

        // Content is clipped to the body so it is revealed as the menu grows
        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: trashCol
                x: trashGeo.contentX + 8
                y: trashGeo.contentY + 8
                width: trashGeo.finalWidth - 16
                spacing: 4
                opacity: trashGeo.contentOpacity

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
    }

    // Launcher button's right-click menu
    DockLauncherMenu {
        id: launcherMenu
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: dockCapsule.x
        dockCapsuleY: dockCapsule.y
        dockCapsuleWidth: dockCapsule.width
        dockCapsuleHeight: dockCapsule.height
        dockCornerRadius: root.startCornerRadius
    }

    // App Picker Popup
    DockAppPicker {
        id: appPicker
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: dockCapsule.x
        dockCapsuleY: dockCapsule.y
        dockCapsuleWidth: dockCapsule.width
        dockCapsuleHeight: dockCapsule.height
        dockCornerRadius: root.startCornerRadius
    }

    // Dismiss overlay to close popups on outside click
    MouseArea {
        id: dismissOverlay
        anchors.fill: parent
        z: -1
        enabled: root.hasOpenPopups
        onClicked: {
            root.closeAllPopups();
        }
    }
}
