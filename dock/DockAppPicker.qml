import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../services/launcherExtras.js" as LauncherExtras

Item {
    id: root

    property bool isOpen: false
    // The centred launcher's body, for the window's blur
    property alias body: centeredBody
    property string searchText: ""
    // The search as typed. searchText is lower-cased for matching apps.
    property string rawSearch: ""
    // Set once the arrow keys move through the app list, so Enter opens that app and not the extra
    property bool listNavigated: false
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

    // Centred (SpotlightWindow): drops out of the rect given by origin* (the island
    // pill) into the middle of its parent, instead of growing out of the dock
    property bool centered: false
    property real originY: 0
    property real originWidth: 0
    property real originHeight: 0
    property real originRadius: 0
    property real popProgress: (centered && isOpen) ? 1.0 : 0.0
    Behavior on popProgress {
        NumberAnimation {
            duration: root.isOpen ? Theme.animDuration : Theme.animDurationFast
            easing.type: root.isOpen ? Theme.animEasing : Easing.OutCubic
            easing.overshoot: Theme.animOvershoot
        }
    }

    // How far open the launcher is (0 to 1), and the current radius of the dock
    // corner it sits on; the dock straightens that corner as the launcher opens
    readonly property real openProgress: centered ? popProgress : geo.progress
    property real dockCornerRadius: Theme.dockRadius

    // Width of the apps side; the settings column is added to it while there are pages to show
    readonly property real mainWidth: gridCols >= 5 ? 540 : 460
    readonly property real wantedWidth: root.mainWidth + (root.settingsColumn ? Theme.launcherSettingsPaneWidth : 0)
    // A launcher that reaches the end of a horizontal dock, or goes past it, would leave
    // a notch against the dock's rounded corner. It then covers the whole dock instead of
    // ending just short of it, and the dock straightens that corner under it.
    readonly property bool reachesDockEnd: !root.centered && !root.isVertical && root.dockCapsuleWidth > 0 && root.wantedWidth >= root.dockCapsuleWidth - Theme.dockRadius - geo.filletSize
    property real dockEndProgress: root.reachesDockEnd ? root.openProgress : 0
    Behavior on dockEndProgress {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    // Full size of the launcher; animates when the layout settings change
    property real finalWidth: root.reachesDockEnd ? Math.max(root.wantedWidth, root.dockCapsuleWidth) : root.wantedWidth
    // Room above the dock (or the whole height beside a vertical dock), so the top is not cut off
    readonly property real maxHeight: {
        let h = root.parent ? root.parent.height : 1000;
        if (root.centered) return h - 64;
        if (root.isVertical) return h - Theme.launcherEdgeMargin;
        let dockTop = root.dockCapsuleY > 0 ? root.dockCapsuleY : (h - Theme.dockHeight);
        return dockTop - Theme.launcherEdgeMargin;
    }
    // Taller while apps and files are listed together
    property real finalHeight: root.combinedFiles ? Math.min(isCompact ? Theme.launcherCombinedHeightCompact : Theme.launcherCombinedHeight, root.maxHeight) : (isCompact ? 440 : 480)

    Behavior on finalWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on finalHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // The launcher is an extension of the dock: it grows out of the corner by the
    // launcher button, with its side continuing the end of the dock in one line.
    DockFlyoutGeometry {
        id: geo
        open: root.isOpen && !root.centered
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        dockCapsuleX: root.dockCapsuleX
        dockCapsuleY: root.dockCapsuleY
        dockCapsuleWidth: root.dockCapsuleWidth
        dockCapsuleHeight: root.dockCapsuleHeight
        align: "start"
        finalWidth: root.finalWidth
        finalHeight: root.finalHeight
        parentWidth: root.parent ? root.parent.width : 1000
        parentHeight: root.parent ? root.parent.height : 1000
    }

    visible: openProgress > 0.001
    opacity: centered ? 1.0 : Math.min(1.0, geo.progress * 4)

    // Centred, the top stays put when the launcher grows for file results
    readonly property real centeredY: {
        let h = root.parent ? root.parent.height : 1000;
        let baseHeight = root.isCompact ? 440 : 480;
        return Math.round(Math.max(Theme.launcherEdgeMargin, Math.min((h - baseHeight) / 2, h - root.finalHeight - Theme.launcherEdgeMargin)));
    }

    readonly property real centeredWidth: originWidth + (finalWidth - originWidth) * popProgress

    x: centered ? Math.round(((root.parent ? root.parent.width : 1000) - centeredWidth) / 2) : geo.x
    y: centered ? originY + (centeredY - originY) * popProgress : geo.y
    width: centered ? centeredWidth : geo.width
    height: centered ? Math.max(0, originHeight + (finalHeight - originHeight) * popProgress) : geo.height

    // System Settings pages that fit the typed text, in a column beside the apps. Two letters
    // are enough to start; the file search key and the window switcher leave it out.
    readonly property string settingsQuery: (SettingsService.launcherSettingsSearch && !root.isWindowMode && !root.fileMode && root.rawSearch) ? root.rawSearch.trim() : ""
    readonly property var settingsPages: root.settingsQuery.length >= 2 ? SettingsPagesService.search(root.settingsQuery) : []
    readonly property bool settingsColumn: root.settingsPages.length > 0
    // Arrow keys move in the settings column instead of the apps (Tab switches)
    property bool settingsFocused: false

    onSettingsPagesChanged: {
        if (settingsList) settingsList.currentIndex = 0;
        root.settingsFocused = false;
    }

    // Enter goes to the settings column when it has focus, or when no app matched
    readonly property bool settingsActive: root.settingsColumn && !root.filesFocused && (root.settingsFocused || (root.filteredApps.length === 0 && !(root.extra && !root.listNavigated)))

    function openSettingsPage(page) {
        SettingsPagesService.open(page);
        root.close();
    }

    function openCurrentSettingsPage() {
        let list = root.settingsPages;
        if (list.length === 0) return;
        let idx = settingsList ? settingsList.currentIndex : 0;
        if (idx < 0 || idx >= list.length) idx = 0;
        root.openSettingsPage(list[idx]);
    }

    // Up and Down while the settings column has focus
    function moveInSettings(dir) {
        let n = root.settingsPages.length;
        if (n === 0) return;
        settingsList.currentIndex = Math.max(0, Math.min(n - 1, settingsList.currentIndex + dir));
        settingsList.positionViewAtIndex(settingsList.currentIndex, ListView.Contain);
    }

    // Tab moves between the apps and the settings column
    function toggleSettingsFocus() {
        if (!root.settingsColumn) return false;
        root.settingsFocused = !root.settingsFocused;
        if (root.settingsFocused) {
            root.filesFocused = false;
            root.listNavigated = true;
            settingsList.currentIndex = 0;
            settingsList.positionViewAtBeginning();
        }
        return true;
    }

    // File search: the words after the key ("f report"), or null when it is not asked for.
    // While it is, the files take the place of the apps; app search itself is untouched.
    readonly property var fileQuery: (SettingsService.launcherFileSearch && !root.isWindowMode) ? LauncherExtras.fileQuery(root.rawSearch, SettingsService.launcherFileSearchKey) : null
    readonly property bool fileMode: fileQuery !== null
    readonly property string homeDir: Quickshell.env("HOME") || ""

    // Plain typing also searches files when file search is on: the apps stay first and
    // the files follow below a line, after a longer pause so launching an app does not
    // walk the folder. Calculator, conversion and web answers skip it.
    readonly property string plainFileQuery: {
        if (!SettingsService.launcherFileSearch || !FileSearchService.available || root.isWindowMode || root.fileMode || root.extra) return "";
        let t = root.rawSearch ? root.rawSearch.trim() : "";
        return t.length >= 3 ? t : "";
    }
    readonly property bool combinedFiles: plainFileQuery !== ""
    // The text sent to Filehouse, or null when no file search is wanted
    readonly property var fileSearchText: root.fileMode ? root.fileQuery : (root.combinedFiles ? root.plainFileQuery : null)
    // Arrow keys move in the file list instead of the apps (combined view only)
    property bool filesFocused: false

    onFileSearchTextChanged: {
        if (root.fileSearchText === null) FileSearchService.clear();
        else FileSearchService.search(root.fileSearchText, root.fileMode ? 250 : 700);
        if (fileListView) fileListView.currentIndex = 0;
        root.filesFocused = false;
    }

    readonly property string fileStatus: {
        if (!FileSearchService.available) return "Filehouse is not installed, so files cannot be searched";
        if (FileSearchService.error !== "") return FileSearchService.error;
        if (root.fileSearchText === "") return "Type a name to search in " + SettingsService.launcherFileSearchRoot;
        let n = FileSearchService.results.length;
        if (FileSearchService.searching) return n > 0 ? n + " found, searching…" : "Searching…";
        if (n === 0) return "No files found";
        return (FileSearchService.more ? "First " + n + " shown" : n + " found") + "  ·  Enter opens, Alt+Enter shows in folder";
    }

    // Room kept at the bottom of the app area for the files in the combined view
    // It takes what the taller launcher adds, so the apps keep their usual room, and gets
    // shorter when the screen or the dock leaves less (a bottom dock caps the height)
    readonly property real filePaneHeight: {
        let wanted = root.isCompact ? Theme.launcherFilePaneHeightCompact : Theme.launcherFilePaneHeight;
        let extra = root.finalHeight - (root.isCompact ? 440 : 480) - 12;
        return Math.min(wanted, Math.max(Theme.px(110), extra));
    }
    readonly property real filePaneSpace: root.combinedFiles ? root.filePaneHeight + 12 : 0

    // Enter on a file opens it with its default app; Alt+Enter shows it in Filehouse
    function openFile(item, showInFolder) {
        if (!item) return;
        if (showInFolder) {
            Quickshell.execDetached(["filehouse", item.path]);
        } else {
            Qt.openUrlExternally(LauncherExtras.fileUrl(item.path));
        }
        root.close();
    }

    // Enter in the combined view opens the file when it is selected, or when no app matched.
    // Alt+Enter always shows the file in its folder.
    function fileEnter(showInFolder) {
        // Results of an earlier query stay until the new search starts; they are not opened
        if (!root.combinedFiles || FileSearchService.hasPending || FileSearchService.results.length === 0) return false;
        if (!root.filesFocused && (root.filteredApps.length > 0 || root.settingsActive)) return false;
        root.openCurrentFile(showInFolder);
        return true;
    }

    // Down and Up in the combined view cross between the apps and the files.
    // Returns false when the key should move inside the app list as usual.
    function moveInCombined(dir) {
        let files = FileSearchService.results.length;
        if (root.filesFocused) {
            if (dir > 0) {
                fileListView.currentIndex = Math.min(files - 1, fileListView.currentIndex + 1);
                fileListView.positionViewAtIndex(fileListView.currentIndex, ListView.Contain);
            } else if (fileListView.currentIndex > 0) {
                fileListView.currentIndex--;
                fileListView.positionViewAtIndex(fileListView.currentIndex, ListView.Contain);
            } else if (root.filteredApps.length > 0) {
                root.filesFocused = false;
            }
            return true;
        }
        if (dir < 0 || files === 0) return false;
        let apps = root.filteredApps.length;
        let view = root.isGrid ? appGridView : appListView;
        let step = root.isGrid ? root.gridCols : 1;
        // On the last row of apps, Down goes on to the files
        if (apps === 0 || Math.floor(view.currentIndex / step) >= Math.floor((apps - 1) / step)) {
            root.filesFocused = true;
            root.settingsFocused = false;
            fileListView.currentIndex = 0;
            fileListView.positionViewAtBeginning();
            root.listNavigated = true;
            return true;
        }
        return false;
    }

    function openCurrentFile(showInFolder) {
        let list = FileSearchService.results;
        if (list.length === 0) return;
        let idx = fileListView ? fileListView.currentIndex : 0;
        if (idx < 0 || idx >= list.length) idx = 0;
        root.openFile(list[idx], showInFolder);
    }

    // Calculator, unit conversion or web search answer for the typed text, shown above the
    // apps. It never changes the app list itself.
    readonly property var extra: {
        if (root.isWindowMode || !root.rawSearch || root.fileMode) return null;
        return LauncherExtras.answer(root.rawSearch, {
            calculator: SettingsService.launcherCalculator,
            conversion: SettingsService.launcherConversion,
            web: SettingsService.launcherWebSearch,
            shortcuts: SettingsService.launcherWebShortcuts
        });
    }

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
            SettingsPagesService.load();
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
            root.rawSearch = "";
            root.settingsFocused = false;
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

    // Enter on the extra: open the search in the browser, or copy the result
    function runExtra() {
        let e = root.extra;
        if (!e) return;
        if (e.url) {
            Qt.openUrlExternally(e.url);
        } else if (e.copy) {
            copyProc.command = ["wl-copy", "--", e.copy];
            copyProc.running = true;
        }
        root.close();
    }

    Process {
        id: copyProc
    }

    function launchCurrentApp() {
        if (root.settingsActive) {
            root.openCurrentSettingsPage();
            return;
        }
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
        visible: !root.centered
        isVertical: root.isVertical
        dockPosition: root.dockPosition
        filletSize: geo.filletSize
        startFlush: geo.startFlush
        dockCornerRadius: root.dockCornerRadius
        farFillet: geo.farFillet
        farOverhang: geo.farOverhang
        cornerRadius: Theme.corner(18)
        tintAlpha: Theme.dockPopupAlpha
    }

    // Free-standing body when centred, in the island's colours so it reads as the
    // pill stretching down
    Rectangle {
        id: centeredBody
        visible: root.centered
        anchors.fill: parent
        radius: Math.min(height / 2, root.originRadius + (Theme.corner(18) - root.originRadius) * Math.min(1, root.popProgress))
        color: Theme.menuSurface
        border.color: Theme.glass ? Theme.islandBorder : Theme.overlay(0.1)
        border.width: 1

        GlassSurface {
            body: centeredBody
        }
    }

    // Content is clipped to the body so it is revealed as the launcher grows
    Item {
        id: contentClip
        anchors.fill: parent
        clip: true

        // Full-size content area; rides out with the growing body
        Item {
            id: contentArea
            x: root.centered ? (root.width - root.finalWidth) / 2 : geo.contentX
            y: root.centered ? 0 : geo.contentY
            width: root.finalWidth
            height: root.finalHeight
            opacity: root.centered ? Math.max(0, Math.min(1, (root.popProgress - 0.4) / 0.6)) : geo.contentOpacity

            // Clicking on the background returns focus to search input
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    searchInput.forceActiveFocus();
                }
            }

            ColumnLayout {
                id: mainColumn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 14
                width: root.mainWidth - 28
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
                            color: Theme.overlay(0.08)

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
                        color: viewToggleMouse.containsMouse ? Theme.overlay(0.16) : Theme.overlay(0.08)
                        border.color: Theme.overlay(0.1)
                        border.width: 1

                        Row {
                            id: viewToggleRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.isGrid ? "list" : "grid"
                                size: 12
                                color: Theme.accentCyanStrong
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
                        color: editMenuMouse.containsMouse ? Theme.overlay(0.16) : Theme.overlay(0.08)

                        Row {
                            id: editMenuRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "settings"
                                size: 11
                                color: Theme.accentOrangeStrong
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
                        color: krunnerMouse.containsMouse ? Theme.overlay(0.16) : Theme.overlay(0.08)

                        Row {
                            id: krunnerRow
                            anchors.centerIn: parent
                            spacing: 5

                            SvgIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bolt"
                                size: 11
                                color: Theme.accentText
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "KRunner"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.accentText
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
                        color: closeHover.containsMouse ? Theme.overlay(0.18) : Theme.overlay(0.08)

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
                    radius: Theme.corner(9)
                    color: Theme.overlay(0.08)
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.overlay(0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        SvgIcon {
                            name: "search"
                            size: 14
                            color: searchInput.activeFocus ? Theme.accent : Theme.textSecondary
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            focus: true
                            activeFocusOnTab: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textPrimary
                            selectionColor: Theme.accentTint(0.4)
                            selectedTextColor: Theme.textPrimary
                            clip: true
                            selectByMouse: true
                            cursorVisible: activeFocus
                            onTextChanged: {
                                root.searchText = text.toLowerCase();
                                root.rawSearch = text;
                                root.listNavigated = false;
                                if (appGridView) appGridView.currentIndex = 0;
                                if (appListView) appListView.currentIndex = 0;
                            }

                            // Before the field's own Enter, for the file search and its Alt+Enter
                            Keys.onReturnPressed: function(event) {
                                if (!root.fileMode) {
                                    if (!root.fileEnter((event.modifiers & Qt.AltModifier) !== 0)) event.accepted = false;
                                    return;
                                }
                                root.openCurrentFile((event.modifiers & Qt.AltModifier) !== 0);
                            }
                            Keys.onEnterPressed: function(event) {
                                if (!root.fileMode) {
                                    if (!root.fileEnter((event.modifiers & Qt.AltModifier) !== 0)) event.accepted = false;
                                    return;
                                }
                                root.openCurrentFile((event.modifiers & Qt.AltModifier) !== 0);
                            }

                            onAccepted: {
                                if (root.fileMode) return;
                                if (root.extra && !root.listNavigated) root.runExtra();
                                else root.launchCurrentApp();
                            }

                            Keys.onEscapePressed: function(event) {
                                root.close();
                                event.accepted = true;
                            }

                            Keys.onTabPressed: function(event) {
                                event.accepted = root.toggleSettingsFocus();
                            }

                            Keys.onDownPressed: function(event) {
                                if (root.settingsFocused) { root.moveInSettings(1); event.accepted = true; return; }
                                if (root.combinedFiles && root.moveInCombined(1)) { event.accepted = true; return; }
                                if (root.fileMode) {
                                    if (fileListView.count > 0) {
                                        fileListView.currentIndex = Math.min(fileListView.count - 1, fileListView.currentIndex + 1);
                                        fileListView.positionViewAtIndex(fileListView.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                    return;
                                }
                                root.listNavigated = true;
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
                                if (root.settingsFocused) { root.moveInSettings(-1); event.accepted = true; return; }
                                if (root.combinedFiles && root.moveInCombined(-1)) { event.accepted = true; return; }
                                if (root.fileMode) {
                                    if (fileListView.count > 0) {
                                        fileListView.currentIndex = Math.max(0, fileListView.currentIndex - 1);
                                        fileListView.positionViewAtIndex(fileListView.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                    return;
                                }
                                root.listNavigated = true;
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
                                if (root.settingsFocused) { event.accepted = false; return; }
                                // Files are one column: the arrows move the text cursor
                                if (root.fileMode || root.filesFocused) { event.accepted = false; return; }
                                if (root.isGrid) root.listNavigated = true;
                                if (root.isGrid && appGridView && appGridView.count > 0) {
                                    appGridView.currentIndex = Math.min(appGridView.count - 1, appGridView.currentIndex + 1);
                                    appGridView.positionViewAtIndex(appGridView.currentIndex, GridView.Contain);
                                    event.accepted = true;
                                }
                            }

                            Keys.onLeftPressed: function(event) {
                                // Back from the settings column to the apps
                                if (root.settingsFocused) { root.settingsFocused = false; event.accepted = true; return; }
                                // Files are one column: the arrows move the text cursor
                                if (root.fileMode || root.filesFocused) { event.accepted = false; return; }
                                if (root.isGrid) root.listNavigated = true;
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
                                radius: Theme.corner(9)
                                color: clearMouse.containsMouse ? Theme.overlay(0.22) : Theme.overlay(0.12)

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
                                color: isSelected ? Theme.accent : (catMouse.containsMouse ? Theme.overlay(0.12) : Theme.overlay(0.06))
                                border.color: isSelected ? Theme.accent : Theme.overlay(0.08)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: catPill.isSelected ? Font.DemiBold : Font.Medium
                                    color: catPill.isSelected ? Theme.accentForeground : (catMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
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

                // Calculator, conversion or web search answer
                Rectangle {
                    id: extraCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.extra ? 46 : 0
                    visible: root.extra !== null
                    radius: Theme.corner(12)
                    color: extraMouse.containsMouse ? Theme.accentTint(0.22) : Theme.accentTint(root.listNavigated ? 0.08 : 0.16)
                    border.width: 1
                    border.color: Theme.accentTint(root.listNavigated ? 0.15 : 0.4)

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        SvgIcon {
                            name: root.extra ? (root.extra.kind === "web" ? "search" : (root.extra.kind === "convert" ? "refresh" : "bolt")) : "search"
                            size: 16
                            color: Theme.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.extra ? root.extra.title : ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.extra ? root.extra.subtitle : ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textSecondary
                            }
                        }
                    }

                    MouseArea {
                        id: extraMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runExtra()
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
                        anchors.bottomMargin: 6 + root.filePaneSpace
                        visible: root.isGrid && !root.fileMode && root.filteredApps.length > 0
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

                            readonly property bool isSelected: index === appGridView.currentIndex && !root.filesFocused && !root.settingsFocused
                            readonly property bool pinned: DockService.isPinned(modelData.id)

                            Rectangle {
                                id: gridTile
                                anchors.centerIn: parent
                                width: parent.width - 6
                                height: parent.height - 6
                                radius: Theme.corner(10)

                                color: gridCell.isSelected ? Theme.accentTint(0.24) : (gridHover.hovered ? Theme.overlay(0.10) : Theme.overlay(0.02))
                                border.color: gridCell.isSelected ? Theme.accentTint(0.6) : (gridHover.hovered ? Theme.overlay(0.12) : "transparent")
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 100 } }

                                // Passive, so hovering the pin badge still counts as hovering the tile
                                HoverHandler {
                                    id: gridHover
                                }

                                // Declared before the tile content so the pin badge sits above it
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
                                            scale: gridHover.hovered ? 1.08 : 1.0
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
                                    color: Theme.accent
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
                                    color: gridPinMouse.containsMouse ? Theme.accentTint(0.4) : (Theme.isLight ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(0, 0, 0, 0.6))
                                    visible: gridHover.hovered && !root.isCompact && !modelData.isWindow

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "pin"
                                        size: 9
                                        color: gridCell.pinned ? Theme.accent : Theme.textSecondary
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
                            }
                        }
                    }

                    // 2. List View Mode
                    ListView {
                        id: appListView
                        anchors.fill: parent
                        anchors.bottomMargin: 6 + root.filePaneSpace
                        visible: !root.isGrid && !root.fileMode && root.filteredApps.length > 0
                        clip: true
                        spacing: 3
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        model: root.filteredApps

                        delegate: Rectangle {
                            id: listItemDelegate
                            width: appListView.width
                            height: root.isCompact ? 34 : 42
                            radius: Theme.corner(8)
                            readonly property bool isSelected: index === appListView.currentIndex && !root.filesFocused && !root.settingsFocused
                            readonly property bool pinned: DockService.isPinned(modelData.id)

                            color: isSelected ? Theme.accentTint(0.22) : (itemMouse.containsMouse ? Theme.overlay(0.10) : "transparent")
                            border.color: isSelected ? Theme.accentTint(0.5) : "transparent"
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
                                        color: isSelected ? Theme.overlay(0.8) : Theme.textSecondary
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
                                    radius: Theme.corner(6)
                                    color: closeWinMouse.containsMouse ? Qt.rgba(1, 0.27, 0.23, 0.3) : Theme.overlay(0.06)
                                    border.color: Theme.overlay(0.1)
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
                                    radius: Theme.corner(6)
                                    color: editBtnMouse.containsMouse ? Theme.overlay(0.18) : Theme.overlay(0.06)
                                    border.color: Theme.overlay(0.1)
                                    border.width: 1

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        name: "settings"
                                        size: root.isCompact ? 10 : 11
                                        color: editBtnMouse.containsMouse ? Theme.accentOrangeStrong : Theme.textSecondary
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
                                    radius: Theme.corner(6)
                                    color: pinBtnMouse.containsMouse ? (pinned ? Qt.rgba(1, 0.3, 0.3, 0.25) : Theme.accentTint(0.25)) : (pinned ? Theme.overlay(0.08) : Theme.accentTint(0.15))
                                    border.color: pinned ? Theme.overlay(0.12) : Theme.accentTint(0.4)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: pinned ? "Pinned" : "+ Pin"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: root.isCompact ? 10 : 11
                                        font.weight: Font.Medium
                                        color: pinned ? Theme.textSecondary : Theme.accent
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

                    // 3. File search results (from Filehouse): in place of the apps for the
                    // key, or under the apps, below a line, while typing normally
                    Rectangle {
                        visible: root.combinedFiles
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: filePane.top
                        anchors.bottomMargin: 5
                        height: 1
                        color: Theme.overlay(0.12)
                    }

                    ColumnLayout {
                        id: filePane
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        height: root.combinedFiles ? root.filePaneHeight : parent.height - 6
                        visible: root.fileMode || root.combinedFiles
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            text: root.fileStatus
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: (FileSearchService.error !== "" || !FileSearchService.available) ? Theme.accentOrangeStrong : Theme.textSecondary
                        }

                        ListView {
                            id: fileListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            // A count, so results arriving one by one keep the selection and scroll
                            model: root.fileSearchText !== null ? FileSearchService.results.length : 0

                            delegate: Rectangle {
                                id: fileRow
                                required property int index
                                readonly property var modelData: FileSearchService.results[index] || ({ path: "", name: "", folder: "", dir: false, type: "" })
                                width: fileListView.width
                                height: root.isCompact ? 34 : 42
                                radius: Theme.corner(8)
                                readonly property bool isSelected: index === fileListView.currentIndex && (!root.combinedFiles || root.filesFocused || (root.filteredApps.length === 0 && !FileSearchService.hasPending))

                                color: isSelected ? Theme.accentTint(0.22) : (fileMouse.containsMouse ? Theme.overlay(0.10) : "transparent")
                                border.color: isSelected ? Theme.accentTint(0.5) : "transparent"
                                border.width: isSelected ? 1 : 0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Image {
                                        Layout.preferredWidth: root.isCompact ? 22 : 28
                                        Layout.preferredHeight: root.isCompact ? 22 : 28
                                        source: Quickshell.iconPath(LauncherExtras.fileIconName(fileRow.modelData), fileRow.modelData.dir ? "folder" : "text-x-generic")
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit
                                        mipmap: true
                                        smooth: true
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: fileRow.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: root.isCompact ? 12 : 13
                                            font.weight: fileRow.isSelected ? Font.DemiBold : Font.Medium
                                            color: Theme.textPrimary
                                            elide: Text.ElideMiddle
                                            width: parent.width
                                        }

                                        Text {
                                            text: LauncherExtras.shortFolder(fileRow.modelData.folder, root.homeDir)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: fileRow.isSelected ? Theme.overlay(0.8) : Theme.textSecondary
                                            elide: Text.ElideMiddle
                                            width: parent.width
                                            visible: !root.isCompact
                                        }
                                    }
                                }

                                MouseArea {
                                    id: fileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        root.openFile(fileRow.modelData, mouse.button === Qt.RightButton || (mouse.modifiers & Qt.AltModifier) !== 0);
                                    }
                                }
                            }
                        }
                    }

                    // Empty state when search or category yields no matches
                    Item {
                        anchors.fill: parent
                        anchors.bottomMargin: root.filePaneSpace
                        visible: root.filteredApps.length === 0 && !root.extra && !root.fileMode

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            SvgIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "search"
                                size: 32
                                color: Theme.overlay(0.2)
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

            // System Settings pages that fit the search, in a column beside the apps
            Rectangle {
                visible: root.settingsColumn
                x: root.mainWidth - 7
                y: 14
                width: 1
                height: parent.height - 28
                color: Theme.overlay(0.12)
            }

            ColumnLayout {
                id: settingsPane
                visible: root.settingsColumn
                x: root.mainWidth + 7
                y: 14
                width: Theme.launcherSettingsPaneWidth - 21
                height: parent.height - 28
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Text {
                        text: "Settings"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                    }

                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: settingsCountText.implicitWidth + 12
                        radius: 9
                        color: Theme.overlay(0.08)

                        Text {
                            id: settingsCountText
                            anchors.centerIn: parent
                            text: "" + root.settingsPages.length
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Theme.textSecondary
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: root.settingsFocused ? "Up and Down choose, Enter opens, Tab goes back" : "Tab to choose a page"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                }

                ListView {
                    id: settingsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.settingsPages

                    delegate: Rectangle {
                        id: pageRow
                        required property int index
                        required property var modelData
                        width: settingsList.width
                        height: root.isCompact ? 38 : 46
                        radius: Theme.corner(8)
                        readonly property bool isSelected: index === settingsList.currentIndex && root.settingsActive

                        color: isSelected ? Theme.accentTint(0.22) : (pageMouse.containsMouse ? Theme.overlay(0.10) : "transparent")
                        border.color: isSelected ? Theme.accentTint(0.5) : "transparent"
                        border.width: isSelected ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Image {
                                Layout.preferredWidth: root.isCompact ? 22 : 28
                                Layout.preferredHeight: root.isCompact ? 22 : 28
                                source: Quickshell.iconPath(pageRow.modelData.icon, "preferences-system")
                                sourceSize.width: 64
                                sourceSize.height: 64
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                smooth: true
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: pageRow.modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: root.isCompact ? 12 : 13
                                    font.weight: pageRow.isSelected ? Font.DemiBold : Font.Medium
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: pageRow.modelData.comment
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: pageRow.isSelected ? Theme.overlay(0.8) : Theme.textSecondary
                                    elide: Text.ElideRight
                                    width: parent.width
                                    visible: !root.isCompact && text !== ""
                                }
                            }
                        }

                        MouseArea {
                            id: pageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (root.settingsActive) settingsList.currentIndex = pageRow.index;
                            }
                            onClicked: root.openSettingsPage(pageRow.modelData)
                        }
                    }
                }
            }
        }
    }
}
