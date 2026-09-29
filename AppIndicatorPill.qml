import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: root

    property bool isTopBarMode: false
    property bool hasFullscreenApp: false
    property bool isIslandExpanded: false

    signal collapseIslandRequested()

    // Currently open context menu item
    property var selectedMenuItem: null
    readonly property bool contextMenuOpen: selectedMenuItem !== null && !hasFullscreenApp

    z: root.contextMenuOpen ? 200 : 1

    function closeContextMenu() {
        if (root.selectedMenuItem) {
            root.selectedMenuItem = null;
        }
    }

    // Filtered list of persistent application items
    property var appItems: []
    readonly property int appCount: appItems.length

    // Hover state matching IslandPill: expands capsule smoothly on pill hover (disabled in full screen / top-bar mode)
    readonly property bool isPillHovered: pillHoverHandler.hovered && !root.contextMenuOpen && !root.isTopBarMode && !root.hasFullscreenApp

    readonly property bool isEnabled: SettingsService.showAppTrayPill
    onIsEnabledChanged: {
        if (!isEnabled && contextMenuOpen) closeContextMenu();
    }

    // Target dimensions matching TopRightStatusCluster morphing physics
    readonly property real compactWidth: contentRow.implicitWidth + (root.isTopBarMode ? Theme.px(14) : Theme.px(20)) + (root.isPillHovered ? Theme.px(8) : 0)
    readonly property real expandedWidth: Math.max(Theme.px(215), Math.max(compactWidth, menuContent.implicitWidth + Theme.px(24)))
    readonly property real targetWidth: !root.isEnabled ? 0 : (root.contextMenuOpen ? expandedWidth : (root.appCount > 0 ? compactWidth : 0))

    readonly property real compactHeight: root.isTopBarMode ? (Theme.topBarHeight + 1) : Theme.compactHeight
    readonly property real expandedHeight: Theme.px(40) + menuContent.implicitHeight + Theme.px(14)
    readonly property real targetHeight: root.contextMenuOpen ? expandedHeight : compactHeight

    readonly property real targetTopRadius: {
        if (root.isTopBarMode) return 0;
        return root.contextMenuOpen ? Theme.expandedRadius : Theme.compactRadius;
    }

    readonly property real targetBottomRadius: {
        return root.contextMenuOpen ? Theme.expandedRadius : (root.isTopBarMode ? 0 : Theme.compactRadius);
    }

    implicitWidth: pillBackground.width
    implicitHeight: pillBackground.height
    width: implicitWidth
    height: implicitHeight

    property alias hitBox: pillBackground

    // Ignored system utilities and desktop daemons that are not user applications
    readonly property var ignoredPatterns: [
        "xwayland video bridge",
        "xwaylandvideobridge",
        "discover notifier",
        "org.kde.discovernotifier",
        "plasma",
        "org.kde.plasma",
        "kdeconnect",
        "kded",
        "powerdevil",
        "bluedevil",
        "kmix",
        "systemsettings"
    ]

    // Well-known application identifiers that qualify as constant app indicators
    readonly property var knownAppPatterns: [
        "discord",
        "steam",
        "spotify",
        "slack",
        "telegram",
        "obs",
        "signal",
        "element",
        "skype",
        "teams",
        "zoom",
        "vlc",
        "dropbox",
        "nextcloud",
        "thunderbird",
        "clementine",
        "strawberry",
        "lutris",
        "heroic",
        "prismlauncher"
    ]

    // Helper to test if a SystemTrayItem represents an active application
    function isAppItem(item) {
        if (!item || !item.id) return false;
        let idLower = (item.id || "").toLowerCase();
        let titleLower = (item.title || "").toLowerCase();
        let descLower = (item.tooltipDescription || "").toLowerCase();
        let combined = idLower + " " + titleLower + " " + descLower;

        // Exclude ignored system background daemons
        for (let i = 0; i < root.ignoredPatterns.length; i++) {
            if (combined.indexOf(root.ignoredPatterns[i]) >= 0) {
                return false;
            }
        }

        // Include recognized applications
        for (let j = 0; j < root.knownAppPatterns.length; j++) {
            if (combined.indexOf(root.knownAppPatterns[j]) >= 0) {
                return true;
            }
        }

        // Application status or communication categories (StatusNotifierItem category 2 or 3)
        if (item.category === 2 || item.category === 3) {
            return true;
        }

        // Include any item with an icon that isn't hardware (0) or system (1)
        if (item.category !== 0 && item.category !== 1 && item.icon && item.icon.length > 0) {
            return true;
        }

        return false;
    }

    // Clean display title for tooltips and headers
    function getAppTitle(item) {
        if (!item) return "";
        if (item.tooltipDescription && item.tooltipDescription.trim().length > 0) {
            return item.tooltipDescription.trim();
        }
        if (item.tooltipTitle && item.tooltipTitle.trim().length > 0) {
            return item.tooltipTitle.trim();
        }
        if (item.title && item.title.trim().length > 0) {
            return item.title.trim();
        }
        let raw = item.id || "";
        let clean = raw.replace(/_status_icon.*$/i, "")
                       .replace(/_tray.*$/i, "")
                       .replace(/^org\.[^.]+\./i, "")
                       .replace(/[-_.]/g, " ")
                       .trim();
        if (clean.length > 0) {
            return clean.charAt(0).toUpperCase() + clean.slice(1);
        }
        return "Application";
    }

    // Resolves a fallback icon from the system theme if the SNI pixmap is unavailable
    function getFallbackIcon(item) {
        if (!item) return "";
        let raw = (item.id || "").toLowerCase();
        if (raw.indexOf("discord") >= 0) return "image://icon/discord";
        if (raw.indexOf("steam") >= 0) return "image://icon/steam";
        if (raw.indexOf("spotify") >= 0) return "image://icon/spotify";
        if (raw.indexOf("slack") >= 0) return "image://icon/slack";
        if (raw.indexOf("telegram") >= 0) return "image://icon/telegram";
        if (raw.indexOf("obs") >= 0) return "image://icon/obs";
        if (raw.indexOf("signal") >= 0) return "image://icon/signal";
        if (raw.indexOf("element") >= 0) return "image://icon/element";
        if (raw.indexOf("skype") >= 0) return "image://icon/skype";
        if (raw.indexOf("teams") >= 0) return "image://icon/teams";
        if (raw.indexOf("zoom") >= 0) return "image://icon/zoom";
        if (raw.indexOf("vlc") >= 0) return "image://icon/vlc";
        if (raw.indexOf("dropbox") >= 0) return "image://icon/dropbox";
        if (raw.indexOf("thunderbird") >= 0) return "image://icon/thunderbird";
        return "image://icon/application-x-executable";
    }

    // Activate application (both SNI activate and KWin window raise)
    function activateApp(item) {
        if (!item) return;

        // Native StatusNotifierItem activation
        if (typeof item.activate === "function") {
            item.activate();
        }

        // Also search for matching window in KWin/Wayland to ensure immediate foreground focus
        let idLower = (item.id || "").toLowerCase();
        let wins = DockService.getMergedWindows();
        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            let wApp = (w.appId || "").toLowerCase();
            let wTitle = (w.title || "").toLowerCase();
            if ((idLower.indexOf("discord") >= 0 && (wApp.indexOf("discord") >= 0 || wTitle.indexOf("discord") >= 0)) ||
                (idLower.indexOf("steam") >= 0 && (wApp.indexOf("steam") >= 0 || wTitle.indexOf("steam") >= 0)) ||
                (idLower.indexOf("spotify") >= 0 && (wApp.indexOf("spotify") >= 0 || wTitle.indexOf("spotify") >= 0)) ||
                (idLower.length > 3 && (wApp.indexOf(idLower) >= 0 || wTitle.indexOf(idLower) >= 0))) {
                if (w.isKWin) {
                    WindowService.activateWindow(w.id);
                } else if (w.raw && typeof w.raw.activate === "function") {
                    if (w.raw.minimized) w.raw.minimized = false;
                    w.raw.activate();
                }
                break;
            }
        }
    }

    // Refresh active application list
    function refreshItems() {
        let list = [];
        let seenKeys = {};

        // 1. Gather all active SystemTray StatusNotifierItems
        if (SystemTray.items && SystemTray.items.values) {
            let vals = SystemTray.items.values;
            for (let i = 0; i < vals.length; i++) {
                let it = vals[i];
                if (root.isAppItem(it)) {
                    let rawId = (it.id || "").toLowerCase();
                    let normKey = rawId.replace(/_status_icon.*$/i, "").replace(/[-_.]/g, "");
                    if (rawId.indexOf("discord") >= 0) normKey = "discord";
                    else if (rawId.indexOf("steam") >= 0) normKey = "steam";
                    else if (rawId.indexOf("spotify") >= 0) normKey = "spotify";

                    if (!seenKeys[normKey]) {
                        seenKeys[normKey] = true;
                        list.push(it);
                    }
                }
            }
        }

        // 2. Check open windows for target constant apps that might not have registered SNI
        let mergedWins = DockService.getMergedWindows();
        for (let w = 0; w < mergedWins.length; w++) {
            let win = mergedWins[w];
            let winApp = (win.appId || "").toLowerCase();
            let winTitle = (win.title || "").toLowerCase();

            for (let p = 0; p < root.knownAppPatterns.length; p++) {
                let pat = root.knownAppPatterns[p];
                if ((winApp.indexOf(pat) >= 0 || winTitle.indexOf(pat) >= 0) && !seenKeys[pat]) {
                    seenKeys[pat] = true;
                    list.push({
                        id: pat,
                        title: pat.charAt(0).toUpperCase() + pat.slice(1),
                        tooltipDescription: win.title || pat,
                        icon: DockService.resolveIcon(pat),
                        isWindowOnly: true,
                        windowId: win.id,
                        activate: function() {
                            WindowService.activateWindow(win.id);
                        },
                        secondaryActivate: function() {
                            WindowService.activateWindow(win.id);
                        }
                    });
                    break;
                }
            }
        }

        // Only update property if items list actually changed to prevent QML binding churn
        let changed = (list.length !== root.appItems.length);
        if (!changed) {
            for (let m = 0; m < list.length; m++) {
                if (list[m].id !== root.appItems[m].id || list[m].icon !== root.appItems[m].icon) {
                    changed = true;
                    break;
                }
            }
        }

        if (changed) {
            root.appItems = list;
            // Close context menu if the currently selected app is no longer open
            if (root.selectedMenuItem) {
                let found = false;
                for (let n = 0; n < list.length; n++) {
                    if (list[n].id === root.selectedMenuItem.id) {
                        found = true;
                        break;
                    }
                }
                if (!found) root.closeContextMenu();
            }
        }
    }

    Component.onCompleted: {
        root.refreshItems();
    }

    // Watch SystemTray model changes
    Connections {
        target: SystemTray.items ? SystemTray.items : null
        function onValuesChanged() {
            root.refreshItems();
        }
    }

    // Watch window manager changes (apps opened/closed)
    Connections {
        target: WindowService
        function onWindowListChanged() {
            root.refreshItems();
        }
    }

    // Periodic lightweight sync timer to catch apps registering or unregistering
    Timer {
        id: syncTimer
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            root.refreshItems();
        }
    }

    // Native DBusMenu opener for the selected application
    QsMenuOpener {
        id: dbusMenuOpener
        menu: (root.selectedMenuItem && root.selectedMenuItem.hasMenu) ? root.selectedMenuItem.menu : null
    }

    // Smooth spring entrance/exit physics
    scale: (root.isEnabled && root.appCount > 0 && !root.hasFullscreenApp) ? 1.0 : 0.0
    opacity: (root.isEnabled && root.appCount > 0 && !root.hasFullscreenApp) ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: Theme.animEntranceOvershoot
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationFast
        }
    }

    // Ambient drop shadow, morphing smoothly with the pill capsule
    Rectangle {
        id: shadow
        anchors.centerIn: pillBackground
        width: pillBackground.width + Theme.px(12)
        height: pillBackground.height + Theme.px(10)

        topLeftRadius: root.targetTopRadius + Theme.px(4)
        topRightRadius: root.targetTopRadius + Theme.px(4)
        bottomLeftRadius: root.targetBottomRadius + Theme.px(4)
        bottomRightRadius: root.targetBottomRadius + Theme.px(4)

        color: Theme.islandShadow
        opacity: (root.isTopBarMode && !root.contextMenuOpen && pillBackground.height <= root.compactHeight + 1) ? 0.0 : (root.contextMenuOpen ? 0.65 : 0.45)
        visible: opacity > 0.01 && root.appCount > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDurationFast }
        }
    }

    // Morphed Capsule Background: Exactly matches TopRightStatusCluster and IslandPill physics
    Rectangle {
        id: pillBackground
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.targetWidth
        height: root.targetHeight
        clip: true

        HoverHandler {
            id: pillHoverHandler
            enabled: !root.isTopBarMode && !root.hasFullscreenApp
        }

        topLeftRadius: root.targetTopRadius
        topRightRadius: root.targetTopRadius
        bottomLeftRadius: root.targetBottomRadius
        bottomRightRadius: root.targetBottomRadius

        color: (root.isTopBarMode && !root.contextMenuOpen && pillBackground.height <= root.compactHeight + 1) ? "transparent" : Theme.islandBackground
        border.width: root.isTopBarMode ? 0 : 1
        border.color: Theme.islandBorder

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

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
                easing.type: root.contextMenuOpen ? Theme.animEasing : Easing.OutCubic
                easing.overshoot: root.contextMenuOpen ? Theme.animOvershoot : 1.0
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

        // =====================================================================
        // State 1: Compact Row of Application Icons
        // =====================================================================
        Item {
            id: compactContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.compactHeight
            visible: opacity > 0.01
            opacity: root.contextMenuOpen ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.appItems

                    delegate: Rectangle {
                        id: appButton
                        width: 26
                        height: 26
                        radius: 13

                        readonly property bool isSelectedForMenu: root.selectedMenuItem === modelData

                        HoverHandler {
                            id: itemHoverHandler
                            enabled: !root.isTopBarMode && !root.hasFullscreenApp
                        }

                        color: isSelectedForMenu ? Qt.rgba(1, 1, 1, 0.22) : (mouseArea.pressed ? Qt.rgba(1, 1, 1, 0.20) : (itemHoverHandler.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))

                        scale: mouseArea.pressed ? 0.90 : 1.0

                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Application Icon
                        Image {
                            id: appImg
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            sourceSize.width: 48
                            sourceSize.height: 48
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            source: (modelData && modelData.icon && modelData.icon.length > 0) ? modelData.icon : root.getFallbackIcon(modelData)

                            onStatusChanged: {
                                if (status === Image.Error) {
                                    let fb = root.getFallbackIcon(modelData);
                                    if (source !== fb) {
                                        source = fb;
                                    }
                                }
                            }
                        }

                        // Interactive click handler (Left = Focus, Right = Morph into Context Menu)
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: function(mouse) {
                                if (root.isIslandExpanded) {
                                    root.collapseIslandRequested();
                                    return;
                                }
                                if (mouse.button === Qt.RightButton) {
                                    if (root.selectedMenuItem === modelData) {
                                        root.closeContextMenu();
                                    } else {
                                        root.selectedMenuItem = modelData;
                                    }
                                } else {
                                    root.closeContextMenu();
                                    root.activateApp(modelData);
                                }
                            }
                        }

                        // Apple OLED Floating Tooltip Badge
                        Rectangle {
                            id: tooltipBadge
                            anchors.top: parent.bottom
                            anchors.topMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 24
                            width: tooltipText.implicitWidth + 16
                            radius: 12
                            color: Theme.islandBackground
                            border.width: 1
                            border.color: Theme.islandBorder
                            z: 300

                            opacity: (itemHoverHandler.hovered && !mouseArea.pressed && !root.contextMenuOpen && !root.isTopBarMode && !root.hasFullscreenApp) ? 1.0 : 0.0
                            scale: (itemHoverHandler.hovered && !mouseArea.pressed && !root.contextMenuOpen && !root.isTopBarMode && !root.hasFullscreenApp) ? 1.0 : 0.85
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.animDurationTooltip }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutBack; easing.overshoot: Theme.animEntranceOvershoot }
                            }

                            // Subtle shadow under tooltip
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 6
                                height: parent.height + 4
                                radius: 14
                                color: Theme.islandShadow
                                z: -1
                                opacity: 0.5
                            }

                            Text {
                                id: tooltipText
                                anchors.centerIn: parent
                                text: root.getAppTitle(modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // State 2: Morphed Context Menu Options (Fluidly expands inside the pill)
        // =====================================================================
        Item {
            id: morphedMenuArea
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.contextMenuOpen ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDurationFast }
            }

            // Top Header Row with App Icon, Name, and Close (✕)
            Item {
                id: headerArea
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 38

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: root.selectedMenuItem ? ((root.selectedMenuItem.icon && root.selectedMenuItem.icon.length > 0) ? root.selectedMenuItem.icon : root.getFallbackIcon(root.selectedMenuItem)) : ""
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.selectedMenuItem ? root.getAppTitle(root.selectedMenuItem) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: closeHover.containsMouse ? Theme.textPrimary : Theme.textTertiary
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeContextMenu()
                        }
                    }
                }
            }

            // Divider under Header
            Rectangle {
                id: headerDivider
                anchors.top: headerArea.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Options List Column
            ColumnLayout {
                id: menuContent
                anchors.top: headerDivider.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                spacing: 2

                // Native DBusMenu Items (Discord, Steam, Spotify, etc.)
                Repeater {
                    model: (root.selectedMenuItem && root.selectedMenuItem.hasMenu && dbusMenuOpener.children) ? dbusMenuOpener.children.values : []

                    delegate: Item {
                        id: entryDelegate
                        Layout.fillWidth: true
                        Layout.preferredHeight: modelData.isSeparator ? 7 : 26

                        // Separator line
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.10)
                            visible: modelData.isSeparator
                        }

                        // Interactive Action Button
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            visible: !modelData.isSeparator

                            readonly property bool isExitItem: {
                                let t = (modelData.text || "").toLowerCase();
                                return t.indexOf("quit") >= 0 || t.indexOf("exit") >= 0 || t.indexOf("close") >= 0;
                            }

                            color: {
                                if (!modelData.enabled) return "transparent";
                                if (itemMouse.pressed) return Qt.rgba(1, 1, 1, 0.22);
                                if (itemMouse.containsMouse) {
                                    return isExitItem ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : Qt.rgba(1, 1, 1, 0.12);
                                }
                                return "transparent";
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                // Checkmark for toggle items (e.g. Mute / Deafen)
                                Text {
                                    text: "✓"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Theme.accentBlue
                                    visible: modelData.checkState !== Qt.Unchecked
                                    Layout.preferredWidth: visible ? 12 : 0
                                }

                                // Item label
                                Text {
                                    Layout.fillWidth: true
                                    text: (modelData.text || "").replace(/&/g, "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: itemMouse.containsMouse ? Font.Medium : Font.Normal
                                    color: {
                                        if (!modelData.enabled) return Qt.rgba(1, 1, 1, 0.35);
                                        if (itemMouse.containsMouse && parent.parent.isExitItem) return Theme.accentRed;
                                        return Theme.textPrimary;
                                    }
                                    elide: Text.ElideRight
                                }

                                // Small red power icon for Exit / Quit items
                                SvgIcon {
                                    name: "power"
                                    size: 11
                                    color: itemMouse.containsMouse ? Theme.accentRed : Qt.rgba(1, 1, 1, 0.40)
                                    visible: parent.parent.isExitItem
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                enabled: modelData.enabled
                                hoverEnabled: true
                                cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    if (typeof modelData.triggered === "function") {
                                        modelData.triggered();
                                    }
                                    root.closeContextMenu();
                                }
                            }
                        }
                    }
                }

                // Fallback Menu Items (For apps without native DBusMenu)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    visible: !root.selectedMenuItem || !root.selectedMenuItem.hasMenu

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: fallbackFocusMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            SvgIcon {
                                name: "window"
                                size: 12
                                color: Theme.accentBlue
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Focus Window"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: fallbackFocusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedMenuItem) {
                                    root.activateApp(root.selectedMenuItem);
                                }
                                root.closeContextMenu();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    visible: !root.selectedMenuItem || !root.selectedMenuItem.hasMenu

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: fallbackQuitMouse.containsMouse ? Qt.rgba(255/255, 69/255, 58/255, 0.22) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            SvgIcon {
                                name: "power"
                                size: 12
                                color: fallbackQuitMouse.containsMouse ? Theme.accentRed : Qt.rgba(1, 1, 1, 0.40)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Quit " + (root.selectedMenuItem ? root.getAppTitle(root.selectedMenuItem) : "Application")
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: fallbackQuitMouse.containsMouse ? Theme.accentRed : Theme.accentRed
                            }
                        }

                        MouseArea {
                            id: fallbackQuitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedMenuItem && root.selectedMenuItem.windowId) {
                                    WindowService.closeWindow(root.selectedMenuItem.windowId);
                                }
                                root.closeContextMenu();
                            }
                        }
                    }
                }
            }
        }
    }
}
