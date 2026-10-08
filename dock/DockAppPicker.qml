import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool isOpen: false
    property string searchText: ""
    property string selectedCategory: "All"
    property string viewMode: SettingsService.launcherDefaultView || "grid"

    property bool isVertical: false
    property string dockPosition: "bottom"
    property real dockCapsuleX: 0
    property real dockCapsuleY: 0
    property real dockCapsuleWidth: 0
    property real dockCapsuleHeight: 0

    // Set by the dock before opening to start on a specific tab (e.g. "Windows")
    property string pendingCategory: ""
    readonly property bool isWindowMode: selectedCategory === "Windows"
    // Open windows, refreshed while the Windows tab is showing
    property var windowItems: []

    readonly property bool isGrid: viewMode === "grid" && !isWindowMode
    readonly property bool isCompact: SettingsService.launcherDensity === "compact"
    readonly property int gridCols: Math.max(3, Math.min(6, SettingsService.launcherGridColumns || 4))

    signal closed()

    // Point on the dock the launcher grows from (the launcher button)
    property real targetX: dockCapsuleX + dockCapsuleWidth / 2
    property real targetY: dockCapsuleY + dockCapsuleHeight / 2

    // Full size of the launcher; animates when the layout settings change
    property real finalWidth: gridCols >= 5 ? 540 : 460
    property real finalHeight: isCompact ? 440 : 480

    Behavior on finalWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on finalHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // The launcher is an extension of the dock: it grows out of the launcher
    // button with its base flush on the dock edge (no gap).
    DockFlyoutGeometry {
        id: geo
        open: root.isOpen
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: root.dockCapsuleX
        dockCapsuleY: root.dockCapsuleY
        dockCapsuleWidth: root.dockCapsuleWidth
        dockCapsuleHeight: root.dockCapsuleHeight
        targetX: root.targetX
        targetY: root.targetY
        finalWidth: root.finalWidth
        finalHeight: root.finalHeight
        parentWidth: root.parent ? root.parent.width : 1000
        parentHeight: root.parent ? root.parent.height : 1000
    }

    visible: geo.progress > 0.001
    opacity: Math.min(1.0, geo.progress * 4)

    x: geo.x
    y: geo.y
    width: geo.width
    height: geo.height

    readonly property var categoryList: [
        "All", "Recent", "Frequent", "Windows", "Internet", "Development", "Multimedia", "Graphics", "Office", "Games", "System", "Utilities"
    ]

    readonly property var filteredApps: {
        let cat = root.selectedCategory;
        let query = root.searchText ? root.searchText.trim().toLowerCase() : "";

        // Window switcher: open windows, optionally filtered by title / app
        if (cat === "Windows") {
            return (root.windowItems || []).filter(function(w) {
                return !query || w.name.toLowerCase().indexOf(query) >= 0 || w.genericName.toLowerCase().indexOf(query) >= 0;
            });
        }

        let all = DockService.installedApps || [];
        // Touch usageStats so the list re-sorts after a launch
        let usage = DockService.usageStats;
        let list = all.filter(function(app) {
            if (cat === "Recent" || cat === "Frequent") {
                if (!usage[DockService.usageKey(app)]) return false;
            } else if (cat !== "All" && app.category !== cat) {
                return false;
            }
            if (!query) return true;
            return (app.name && app.name.toLowerCase().indexOf(query) >= 0) ||
                   (app.genericName && app.genericName.toLowerCase().indexOf(query) >= 0) ||
                   (app.comment && app.comment.toLowerCase().indexOf(query) >= 0);
        });

        if (cat === "Recent") {
            list.sort(function(a, b) { return DockService.lastUsed(b) - DockService.lastUsed(a); });
            return list.slice(0, 16);
        }
        if (cat === "Frequent") {
            list.sort(function(a, b) { return (DockService.useCount(b) - DockService.useCount(a)) || (DockService.lastUsed(b) - DockService.lastUsed(a)); });
            return list.slice(0, 16);
        }
        // Searching: name matches first (prefix before substring), then most used
        if (query) {
            let rank = function(app) {
                let n = (app.name || "").toLowerCase();
                return n.indexOf(query) === 0 ? 0 : (n.indexOf(query) > 0 ? 1 : 2);
            };
            list.sort(function(a, b) {
                return (rank(a) - rank(b)) || (DockService.useCount(b) - DockService.useCount(a)) || a.name.localeCompare(b.name);
            });
        }
        return list;
    }

    function refreshWindows() {
        root.windowItems = DockService.windowItems();
    }

    // Keep the window list live while the switcher is showing
    Connections {
        target: WindowService
        enabled: root.isOpen && root.isWindowMode
        function onWindowListChanged() { root.refreshWindows(); }
    }

    onSelectedCategoryChanged: {
        if (selectedCategory === "Windows") refreshWindows();
    }

    // Launch an app, or focus a window in the switcher
    function openItem(item) {
        if (!item) return;
        if (item.isWindow) {
            DockService.activateWindow(item.window);
        } else {
            if (DockService.isRunning(item)) DockService.recordUse(item);
            DockService.activateOrLaunch(item);
        }
    }

    function close() {
        root.isOpen = false;
        root.closed();
    }

    // Delegates call this as one step: opening or closing can reset the model
    // and destroy the delegate, after which it can no longer reach root
    function openAndClose(item) {
        root.openItem(item);
        root.close();
    }

    // Secondary action: close a window, or open an app's properties
    function openItemSecondary(item) {
        if (!item) return;
        if (item.isWindow) {
            DockService.closeWindow(item.window);
            Qt.callLater(root.refreshWindows);
        } else {
            DockService.openAppProperties(item.desktopFile || item.id);
            root.close();
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            DockService.updateInstalledApps();
            searchInput.text = "";
            root.searchText = "";
            let startTab = root.pendingCategory || SettingsService.launcherStartTab || "All";
            root.pendingCategory = "";
            // Recent / Frequent are empty until something has been launched
            if ((startTab === "Recent" || startTab === "Frequent") && Object.keys(DockService.usageStats).length === 0) startTab = "All";
            root.selectedCategory = startTab;
            if (startTab === "Windows") root.refreshWindows();
            root.viewMode = SettingsService.launcherDefaultView || "grid";
            if (appGridView) appGridView.currentIndex = 0;
            if (appListView) appListView.currentIndex = 0;
            searchInput.forceActiveFocus();
            focusTimer.restart();
        } else {
            searchInput.text = "";
            root.searchText = "";
            focusTimer.stop();
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (root.isOpen) {
                searchInput.forceActiveFocus();
                searchInput.selectAll();
            }
        }
    }

    function launchCurrentApp() {
        let list = root.filteredApps;
        if (list && list.length > 0) {
            let idx = root.isGrid ? (appGridView ? appGridView.currentIndex : 0) : (appListView ? appListView.currentIndex : 0);
            if (idx < 0 || idx >= list.length) idx = 0;
            let targetApp = list[idx];
            if (targetApp) {
                root.openAndClose(targetApp);
            }
        }
    }

    DockFlyoutBackground {
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        fitsOnDock: geo.fitsOnDock
        filletSize: geo.filletSize
        cornerRadius: 18
        tintAlpha: Theme.dockTransparent ? 0.94 : 0.97
    }

    // Content is clipped to the body so it is revealed as the launcher grows
    Item {
        id: contentClip
        anchors.fill: parent
        clip: true

        // Full-size content area; rides out with the growing body
        Item {
            id: contentArea
            x: geo.contentX
            y: geo.contentY
            width: root.finalWidth
            height: root.finalHeight
            opacity: geo.contentOpacity

            // Clicking on the background returns focus to search input
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    searchInput.forceActiveFocus();
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header: Title + count badge, View Mode switcher, Edit Menu, KRunner, Close
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 6

                    RowLayout {
                        spacing: 8

                        Text {
                            text: root.isWindowMode ? "Windows" : "Applications"
                            font.family: Theme.fontDisplay
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }

                        // App count pill
                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: appCountText.implicitWidth + 12
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                id: appCountText
                                anchors.centerIn: parent
                                text: "" + root.filteredApps.length
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Theme.textSecondary
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // View Mode Toggle (Grid ⇄ List); the window switcher is always a list
                    Rectangle {
                        visible: !root.isWindowMode
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: viewToggleRow.implicitWidth + 14
                        radius: 13
                        color: viewToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1

                        Row {
                            id: viewToggleRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.isGrid ? "list" : "grid"
                                size: 12
                                color: Theme.accentCyan
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.isGrid ? "List" : "Grid"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: viewToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let nextMode = root.isGrid ? "list" : "grid";
                                root.viewMode = nextMode;
                                SettingsService.setSetting("launcherDefaultView", nextMode);
                            }
                        }
                    }

                    // Edit Menu button (KDE Menu Editor)
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: editMenuRow.implicitWidth + 14
                        radius: 13
                        color: editMenuMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            id: editMenuRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "settings"
                                size: 11
                                color: Theme.accentOrange
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Edit"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: editMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                DockService.openMenuEditor();
                                root.close();
                            }
                        }
                    }

                    // KRunner button
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: krunnerRow.implicitWidth + 14
                        radius: 13
                        color: krunnerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            id: krunnerRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bolt"
                                size: 11
                                color: Theme.accentBlue
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "KRunner"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.accentBlue
                            }
                        }

                        MouseArea {
                            id: krunnerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                DockService.openLaunchpad();
                                root.close();
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                        SvgIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                            }
                        }
                    }
                }

                // Search Input Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: searchInput.activeFocus ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        SvgIcon {
                            name: "search"
                            size: 14
                            color: searchInput.activeFocus ? Theme.accentBlue : Theme.textSecondary
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            focus: true
                            activeFocusOnTab: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textPrimary
                            selectionColor: Qt.rgba(0.04, 0.52, 1, 0.4)
                            selectedTextColor: Theme.textPrimary
                            clip: true
                            selectByMouse: true
                            cursorVisible: activeFocus
                            onTextChanged: {
                                root.searchText = text.toLowerCase();
                                if (appGridView) appGridView.currentIndex = 0;
                                if (appListView) appListView.currentIndex = 0;
                            }

                            onAccepted: {
                                root.launchCurrentApp();
                            }

                            Keys.onEscapePressed: function(event) {
                                root.close();
                                event.accepted = true;
                            }

                            Keys.onDownPressed: function(event) {
                                if (root.isGrid) {
                                    if (appGridView && appGridView.count > 0) {
                                        appGridView.currentIndex = Math.min(appGridView.count - 1, appGridView.currentIndex + root.gridCols);
                                        appGridView.positionViewAtIndex(appGridView.currentIndex, GridView.Contain);
                                    }
                                } else {
                                    if (appListView && appListView.count > 0) {
                                        appListView.currentIndex = Math.min(appListView.count - 1, appListView.currentIndex + 1);
                                        appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain);
                                    }
                                }
                                event.accepted = true;
                            }

                            Keys.onUpPressed: function(event) {
                                if (root.isGrid) {
                                    if (appGridView && appGridView.count > 0) {
                                        appGridView.currentIndex = Math.max(0, appGridView.currentIndex - root.gridCols);
                                        appGridView.positionViewAtIndex(appGridView.currentIndex, GridView.Contain);
                                    }
                                } else {
                                    if (appListView && appListView.count > 0) {
                                        appListView.currentIndex = Math.max(0, appListView.currentIndex - 1);
                                        appListView.positionViewAtIndex(appListView.currentIndex, ListView.Contain);
                                    }
                                }
                                event.accepted = true;
                            }

                            Keys.onRightPressed: function(event) {
                                if (root.isGrid && appGridView && appGridView.count > 0) {
                                    appGridView.currentIndex = Math.min(appGridView.count - 1, appGridView.currentIndex + 1);
                                    appGridView.positionViewAtIndex(appGridView.currentIndex, GridView.Contain);
                                    event.accepted = true;
                                }
                            }

                            Keys.onLeftPressed: function(event) {
                                if (root.isGrid && appGridView && appGridView.count > 0) {
                                    appGridView.currentIndex = Math.max(0, appGridView.currentIndex - 1);
                                    appGridView.positionViewAtIndex(appGridView.currentIndex, GridView.Contain);
                                    event.accepted = true;
                                }
                            }

                            Text {
                                anchors.fill: parent
                                text: root.isWindowMode ? "Search open windows..." : "Search installed apps..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textTertiary
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }

                        // Clear button
                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            visible: searchInput.text.length > 0

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)

                                SvgIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 10
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = "";
                                        root.searchText = "";
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // Category Filter Tabs (horizontal scrollable pills)
                Flickable {
                    id: categoryFlickable
                    Layout.fillWidth: true
                    Layout.preferredHeight: SettingsService.launcherShowCategories ? 26 : 0
                    visible: SettingsService.launcherShowCategories
                    contentWidth: categoryRow.implicitWidth
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            categoryFlickable.contentX = Math.max(0, Math.min(categoryFlickable.contentWidth - categoryFlickable.width, categoryFlickable.contentX - (wheel.angleDelta.y || wheel.angleDelta.x)));
                        }
                    }

                    Row {
                        id: categoryRow
                        spacing: 6
                        height: parent.height

                        Repeater {
                            model: root.categoryList

                            Rectangle {
                                id: catPill
                                readonly property bool isSelected: root.selectedCategory === modelData
                                height: 24
                                width: catText.implicitWidth + 16
                                radius: 12
                                color: isSelected ? Theme.accentBlue : (catMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: isSelected ? Theme.accentBlue : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: catPill.isSelected ? Font.DemiBold : Font.Medium
                                    color: catPill.isSelected ? Theme.onAccent : (catMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                }

                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedCategory = modelData;
                                        if (appGridView) appGridView.currentIndex = 0;
                                        if (appListView) appListView.currentIndex = 0;
                                    }
                                }
                            }
                        }
                    }
                }

                // Main App Display Container
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // 1. Grid View Mode
                    GridView {
                        id: appGridView
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        visible: root.isGrid && root.filteredApps.length > 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: 0

                        cellWidth: Math.floor(width / root.gridCols)
                        cellHeight: root.isCompact ? 76 : 90

                        model: root.filteredApps

                        delegate: Item {
                            id: gridCell
                            width: appGridView.cellWidth
                            height: appGridView.cellHeight

                            readonly property bool isSelected: index === appGridView.currentIndex
                            readonly property bool pinned: DockService.isPinned(modelData.id)

                            Rectangle {
                                id: gridTile
                                anchors.centerIn: parent
                                width: parent.width - 6
                                height: parent.height - 6
                                radius: 10

                                color: gridCell.isSelected ? Qt.rgba(0.04, 0.52, 1, 0.24) : (gridMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.02))
                                border.color: gridCell.isSelected ? Qt.rgba(0.04, 0.52, 1, 0.6) : (gridMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: root.isCompact ? 4 : 6
                                    width: parent.width - 8

                                    // App Icon
                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: root.isCompact ? 36 : 46
                                        height: width

                                        Image {
                                            anchors.centerIn: parent
                                            width: parent.width
                                            height: parent.height
                                            source: DockService.resolveIcon(modelData.icon)
                                            sourceSize.width: 96
                                            sourceSize.height: 96
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                            smooth: true
                                            scale: gridMouse.containsMouse ? 1.08 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    // App Name
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.isCompact ? 10 : 11
                                        font.weight: gridCell.isSelected ? Font.DemiBold : Font.Normal
                                        color: Theme.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                // Pinned Indicator Badge
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.accentBlue
                                    visible: gridCell.pinned
                                }

                                // Pin toggle badge on hover
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: gridPinMouse.containsMouse ? Qt.rgba(0.04, 0.52, 1, 0.4) : Qt.rgba(0, 0, 0, 0.6)
                                    visible: gridMouse.containsMouse && !root.isCompact && !modelData.isWindow

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "pin"
                                        size: 9
                                        color: gridCell.pinned ? Theme.accentBlue : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: gridPinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (gridCell.pinned) {
                                                DockService.unpinApp(modelData.id);
                                            } else {
                                                DockService.pinApp(modelData);
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: gridMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        appGridView.currentIndex = index;
                                    }
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            root.openItemSecondary(modelData);
                                        } else {
                                            root.openAndClose(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. List View Mode
                    ListView {
                        id: appListView
                        anchors.fill: parent
                        anchors.bottomMargin: 6
                        visible: !root.isGrid && root.filteredApps.length > 0
                        clip: true
                        spacing: 3
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        model: root.filteredApps

                        delegate: Rectangle {
                            id: listItemDelegate
                            width: appListView.width
                            height: root.isCompact ? 34 : 42
                            radius: 8
                            readonly property bool isSelected: index === appListView.currentIndex
                            readonly property bool pinned: DockService.isPinned(modelData.id)

                            color: isSelected ? Qt.rgba(0.04, 0.52, 1, 0.22) : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                            border.color: isSelected ? Qt.rgba(0.04, 0.52, 1, 0.5) : "transparent"
                            border.width: isSelected ? 1 : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                // App Icon
                                Image {
                                    Layout.preferredWidth: root.isCompact ? 22 : 28
                                    Layout.preferredHeight: root.isCompact ? 22 : 28
                                    source: DockService.resolveIcon(modelData.icon)
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    smooth: true
                                }

                                // App Title & Generic Name
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.isCompact ? 12 : 13
                                        font.weight: isSelected ? Font.DemiBold : Font.Medium
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: modelData.genericName || modelData.comment || ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        color: isSelected ? Qt.rgba(1, 1, 1, 0.8) : Theme.textSecondary
                                        elide: Text.ElideRight
                                        width: parent.width
                                        visible: SettingsService.launcherShowGenericNames && !root.isCompact && text.length > 0
                                    }
                                }

                                // Close Window Button (window switcher only)
                                Rectangle {
                                    visible: !!modelData.isWindow
                                    Layout.preferredWidth: root.isCompact ? 22 : 24
                                    Layout.preferredHeight: root.isCompact ? 22 : 24
                                    radius: 6
                                    color: closeWinMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: root.isCompact ? 10 : 11
                                        color: closeWinMouse.containsMouse ? Theme.accentRed : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: closeWinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openItemSecondary(modelData)
                                    }
                                }

                                // Edit Application Properties Button
                                Rectangle {
                                    visible: !modelData.isWindow
                                    Layout.preferredWidth: root.isCompact ? 22 : 24
                                    Layout.preferredHeight: root.isCompact ? 22 : 24
                                    radius: 6
                                    color: editBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "settings"
                                        size: root.isCompact ? 10 : 11
                                        color: editBtnMouse.containsMouse ? Theme.accentOrange : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: editBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            DockService.openAppProperties(modelData.desktopFile || modelData.id);
                                            root.close();
                                        }
                                    }
                                }

                                // Pin / Unpin Action Button
                                Rectangle {
                                    visible: !modelData.isWindow
                                    Layout.preferredWidth: root.isCompact ? 54 : 64
                                    Layout.preferredHeight: root.isCompact ? 22 : 24
                                    radius: 6
                                    color: pinBtnMouse.containsMouse ? (pinned ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(0.04, 0.52, 1, 0.25)) : (pinned ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0.04, 0.52, 1, 0.15))
                                    border.color: pinned ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.04, 0.52, 1, 0.4)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: pinned ? "Pinned" : "+ Pin"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.isCompact ? 10 : 11
                                        font.weight: Font.Medium
                                        color: pinned ? Theme.textSecondary : Theme.accentBlue
                                    }

                                    MouseArea {
                                        id: pinBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (pinned) {
                                                DockService.unpinApp(modelData.id);
                                            } else {
                                                DockService.pinApp(modelData);
                                            }
                                        }
                                    }
                                }
                            }

                            // Click to launch (Left click) or edit settings (Right click)
                            MouseArea {
                                id: itemMouse
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.rightMargin: 90
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    appListView.currentIndex = index;
                                }
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.openItemSecondary(modelData);
                                    } else {
                                        root.openAndClose(modelData);
                                    }
                                }
                            }
                        }
                    }

                    // Empty state when search or category yields no matches
                    Item {
                        anchors.fill: parent
                        visible: root.filteredApps.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            SvgIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "search"
                                size: 32
                                color: Qt.rgba(1, 1, 1, 0.2)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.isWindowMode ? "No open windows"
                            : (root.selectedCategory === "Recent" || root.selectedCategory === "Frequent") ? ("Nothing launched yet. " + root.selectedCategory + " apps will show up here.")
                            : (root.selectedCategory !== "All" ? ("No apps found in " + root.selectedCategory) : "No applications found")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                        }
                    }
                }
            }
        }
    }
}
