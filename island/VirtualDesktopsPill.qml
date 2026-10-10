import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool isTopBarMode: false
    property bool hasFullscreenApp: false

    readonly property var desktops: WindowService.virtualDesktops
    readonly property int desktopCount: WindowService.desktopCount
    readonly property int currentIndex: WindowService.currentDesktopIndex
    readonly property string currentId: WindowService.currentDesktopId
    readonly property string currentName: WindowService.currentDesktopName

    // Tooltip state
    property string hoveredTooltipText: ""
    property real hoveredTooltipTargetX: 0
    property bool isTooltipActive: false

    // Context Menu state
    property var activeMenuDesktop: null
    property real activeMenuTargetX: 0
    readonly property bool menuOpen: activeMenuDesktop !== null

    readonly property bool isEnabled: SettingsService.showVirtualDesktops
    onIsEnabledChanged: {
        if (!isEnabled && menuOpen) closeMenu();
    }

    function closeMenu() {
        root.activeMenuDesktop = null;
    }

    function openMenuForDesktop(desktopData, targetX) {
        root.isTooltipActive = false;
        root.activeMenuDesktop = desktopData;
        root.activeMenuTargetX = targetX;
    }

    // Hover state matching IslandPill: expands capsule smoothly on pill hover (disabled in full screen / top-bar mode)
    readonly property bool isHovered: pillHoverHandler.hovered && !root.menuOpen && !root.isTopBarMode && !root.hasFullscreenApp
    readonly property bool isPillHovered: pillHoverHandler.hovered && !root.hasFullscreenApp

    // Geometry
    readonly property real compactWidth: contentRow.implicitWidth + (root.isTopBarMode ? Theme.px(14) : Theme.px(20))
    readonly property real targetWidth: (root.isEnabled && root.desktopCount > 0 && !root.hasFullscreenApp) ? (compactWidth + (root.isHovered ? Theme.px(8) : 0)) : 0
    readonly property real targetHeight: root.isTopBarMode ? (Theme.topBarHeight + 1) : Theme.compactHeight
    readonly property real pillHeight: root.isTopBarMode ? Theme.px(26) : Theme.compactHeight

    width: pillBackground.width
    height: root.targetHeight
    implicitWidth: pillBackground.width
    implicitHeight: root.targetHeight

    property alias hitBox: pillBackground
    property alias menuHitBox: menuPopover

    visible: root.isEnabled && targetWidth > 1
    opacity: (root.isEnabled && targetWidth > 1) ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDurationFast }
    }

    // Soft Ambient Shadow (floating mode only)
    Rectangle {
        id: shadow
        anchors.centerIn: pillBackground
        width: pillBackground.width + Theme.px(10)
        height: pillBackground.height + Theme.px(8)
        radius: pillBackground.radius + Theme.px(3)
        color: Theme.islandShadow
        opacity: root.isTopBarMode ? 0.0 : 0.40
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Pill Capsule Background
    Rectangle {
        id: pillBackground
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.targetWidth
        height: root.pillHeight
        radius: root.isTopBarMode ? Theme.px(13) : Theme.compactRadius
        clip: false

        HoverHandler {
            id: pillHoverHandler
            enabled: !root.hasFullscreenApp
        }

        // Frosted glass appearance
        color: root.isTopBarMode ? Theme.overlay(0.08) : (Theme.isLight ? Qt.rgba(0.97, 0.95, 0.92, 0.8) : Qt.rgba(0.12, 0.12, 0.14, 0.65))
        border.width: 1
        border.color: root.isTopBarMode ? Theme.overlay(0.06) : Theme.overlay(0.09)

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
                easing.type: Easing.OutCubic
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

        // Global wheel handler for fluid scroll switching between workspaces
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: false

            onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0) {
                    WindowService.previousDesktop();
                } else if (wheel.angleDelta.y < 0) {
                    WindowService.nextDesktop();
                }
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.isTopBarMode ? 3 : 5

            Repeater {
                model: root.desktops

                delegate: Item {
                    id: desktopItem
                    required property var modelData
                    required property int index

                    width: root.isTopBarMode ? 24 : 28
                    height: root.isTopBarMode ? 20 : 26

                    readonly property bool isCurrent: !!modelData.isCurrent
                    readonly property int winCount: WindowService.getDesktopWindowCount(modelData.id, modelData.index)

                    // Desktop Item Capsule Button
                    Rectangle {
                        id: itemCard
                        anchors.fill: parent
                        radius: root.isTopBarMode ? 10 : 13

                        color: {
                            if (desktopItem.isCurrent) {
                                return root.isTopBarMode ? Theme.overlay(0.22) : Theme.overlay(0.24);
                            }
                            return "transparent";
                        }

                        border.width: desktopItem.isCurrent ? 1 : 0
                        border.color: desktopItem.isCurrent ? Theme.overlay(0.20) : "transparent"

                        scale: itemMouse.pressed ? 0.90 : 1.0

                        Behavior on color { ColorAnimation { duration: 110 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animDurationTooltip
                                easing.type: Easing.OutCubic
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: desktopItem.winCount > 0 ? 1 : 0

                            // Desktop Number / Label
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(desktopItem.modelData.index + 1)
                                font.family: Theme.fontFamily
                                font.pixelSize: root.isTopBarMode ? 11 : 12
                                font.weight: desktopItem.isCurrent ? Font.Bold : ((itemMouse.containsMouse && !root.isTopBarMode && !root.hasFullscreenApp) ? Font.DemiBold : Font.Normal)
                                color: desktopItem.isCurrent ? Theme.textPrimary : ((itemMouse.containsMouse && !root.isTopBarMode && !root.hasFullscreenApp) ? Theme.textPrimary : Theme.textSecondary)

                                Behavior on color { ColorAnimation { duration: 110 } }
                            }

                            // Workspace-style open window activity dot
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 3
                                height: 3
                                radius: 1.5
                                color: desktopItem.isCurrent ? Theme.overlay(0.85) : Theme.overlay(0.45)
                                visible: desktopItem.winCount > 0
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    WindowService.previousDesktop();
                                } else if (wheel.angleDelta.y < 0) {
                                    WindowService.nextDesktop();
                                }
                            }

                            onEntered: {
                                if (root.menuOpen || root.isTopBarMode || root.hasFullscreenApp) return;
                                let mapped = desktopItem.mapToItem(root, desktopItem.width / 2, 0);
                                let dName = modelData.name || ("Desktop " + (modelData.index + 1));
                                let winText = desktopItem.winCount > 0 ? (" • " + desktopItem.winCount + (desktopItem.winCount === 1 ? " window" : " windows")) : " (Empty)";
                                root.hoveredTooltipText = dName + winText;
                                root.hoveredTooltipTargetX = mapped.x;
                                root.isTooltipActive = true;
                            }

                            onExited: {
                                root.isTooltipActive = false;
                            }

                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    let mapped = desktopItem.mapToItem(root, desktopItem.width / 2, 0);
                                    root.openMenuForDesktop(modelData, mapped.x);
                                } else {
                                    root.closeMenu();
                                    WindowService.switchToDesktop(modelData.id);
                                }
                            }
                        }
                    }
                }
            }

            // Subtle "+" button to add a new virtual desktop
            Rectangle {
                id: addDesktopBtn
                anchors.verticalCenter: parent.verticalCenter
                width: root.isTopBarMode ? 18 : 22
                height: root.isTopBarMode ? 18 : 22
                radius: height / 2
                color: "transparent"
                opacity: (addMouse.containsMouse && !root.isTopBarMode && !root.hasFullscreenApp) ? 1.0 : 0.65

                Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animDurationTooltip
                        easing.type: Easing.OutCubic
                    }
                }

                scale: addMouse.pressed ? 0.88 : 1.0

                SvgIcon {
                    anchors.centerIn: parent
                    name: "plus"
                    size: root.isTopBarMode ? 9 : 10
                    color: (addMouse.containsMouse && !root.isTopBarMode && !root.hasFullscreenApp) ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: !root.isTopBarMode && !root.hasFullscreenApp
                    cursorShape: Qt.PointingHandCursor

                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y > 0) {
                            WindowService.previousDesktop();
                        } else if (wheel.angleDelta.y < 0) {
                            WindowService.nextDesktop();
                        }
                    }

                    onEntered: {
                        if (root.menuOpen || root.isTopBarMode || root.hasFullscreenApp) return;
                        let mapped = addDesktopBtn.mapToItem(root, addDesktopBtn.width / 2, 0);
                        root.hoveredTooltipText = "New Desktop";
                        root.hoveredTooltipTargetX = mapped.x;
                        root.isTooltipActive = true;
                    }

                    onExited: {
                        root.isTooltipActive = false;
                    }

                    onClicked: {
                        root.closeMenu();
                        WindowService.createDesktop("");
                    }
                }
            }
        }
    }

    // Hover Tooltip
    Item {
        id: tooltipWrapper
        anchors.top: pillBackground.bottom
        anchors.topMargin: 8
        x: Math.max(0, Math.min(root.width - tooltipBg.width, root.hoveredTooltipTargetX - tooltipBg.width / 2))
        z: 300

        opacity: (root.isTooltipActive && !root.menuOpen && !root.isTopBarMode && !root.hasFullscreenApp) ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }
        Behavior on x { NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic } }

        Rectangle {
            id: tooltipBg
            width: Math.min(240, tooltipText.implicitWidth + 18)
            height: 24
            radius: Theme.corner(7)
            color: Theme.cardBackground
            border.width: 1
            border.color: Theme.overlay(0.14)

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 6
                radius: Theme.corner(9)
                color: Theme.islandShadow
                opacity: 0.55
                z: -1
            }

            Text {
                id: tooltipText
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.hoveredTooltipText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.textPrimary
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }

    // Context Menu Popover (on right-click)
    Item {
        id: menuPopover
        anchors.top: pillBackground.bottom
        anchors.topMargin: 8
        x: Math.max(0, Math.min(root.width - menuCard.width, root.activeMenuTargetX - menuCard.width / 2))
        width: 180
        height: menuCard.height
        z: 400

        opacity: root.menuOpen ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: Theme.animDurationTooltip } }
        Behavior on x { NumberAnimation { duration: Theme.animDurationPopover; easing.type: Easing.OutCubic } }

        Rectangle {
            id: menuCard
            width: 180
            height: menuColumn.implicitHeight + 14
            radius: Theme.corner(12)
            color: Theme.islandBackground
            border.width: 0
            clip: true

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: parent.height + 8
                radius: Theme.corner(14)
                color: Theme.islandShadow
                opacity: 0.65
                z: -1
            }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 7
                spacing: 3

                // Header caption
                Item {
                    width: parent.width
                    height: 22

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.activeMenuDesktop ? (root.activeMenuDesktop.name || ("Desktop " + (root.activeMenuDesktop.index + 1))) : "Desktop"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }

                // Switch to Desktop
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.corner(7)
                    scale: switchMouse.pressed ? 0.98 : (switchMouse.containsMouse ? 1.02 : 1.0)
                    transformOrigin: Item.Center
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animDurationFast
                            easing.type: Theme.animEasing
                            easing.overshoot: Theme.animOvershoot
                        }
                    }
                    color: switchMouse.containsMouse ? Theme.overlay(0.12) : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        SvgIcon {
                            name: "desktop"
                            size: 13
                            color: Theme.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Switch to Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: switchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuDesktop) {
                                WindowService.switchToDesktop(root.activeMenuDesktop.id);
                            }
                            root.closeMenu();
                        }
                    }
                }

                // Add New Desktop
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.corner(7)
                    scale: addMenuMouse.pressed ? 0.98 : (addMenuMouse.containsMouse ? 1.02 : 1.0)
                    transformOrigin: Item.Center
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animDurationFast
                            easing.type: Theme.animEasing
                            easing.overshoot: Theme.animOvershoot
                        }
                    }
                    color: addMenuMouse.containsMouse ? Theme.overlay(0.12) : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        SvgIcon {
                            name: "plus"
                            size: 13
                            color: Theme.accentGreen
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "New Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: addMenuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            WindowService.createDesktop("");
                            root.closeMenu();
                        }
                    }
                }

                // Remove Desktop (if count > 1)
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.corner(7)
                    visible: root.desktopCount > 1
                    scale: removeMouse.pressed ? 0.98 : (removeMouse.containsMouse ? 1.02 : 1.0)
                    transformOrigin: Item.Center
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animDurationFast
                            easing.type: Theme.animEasing
                            easing.overshoot: Theme.animOvershoot
                        }
                    }
                    color: removeMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.20) : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        SvgIcon {
                            name: "trash"
                            size: 13
                            color: Theme.accentRed
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Remove Desktop"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.accentRed
                        }
                    }

                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeMenuDesktop) {
                                WindowService.removeDesktop(root.activeMenuDesktop.id);
                            }
                            root.closeMenu();
                        }
                    }
                }
            }
        }
    }
}
