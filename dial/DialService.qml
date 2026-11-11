pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "dialLogic.js" as Logic
import "../services/launcherExtras.js" as LauncherExtras

// State of the category dial launcher (experimental, see dial/DialWindow.qml). The views
// read and write this; the clock pill and the IPC handler only flip `open`.
Singleton {
    id: root

    property bool open: false
    // Index into Logic.CATEGORIES
    property int category: 0
    // Remembered app position per category, as { categoryIndex: slot }
    property var focusMemory: ({})

    // Search text, and which of the four scopes (Logic.SCOPES) shows while there is any
    property string query: ""
    property int scope: 0

    readonly property string trimmedQuery: query.trim()
    readonly property bool searching: trimmedQuery !== ""

    // True for a moment after the user moves the ring or the arc, or starts or ends a search.
    // The rings only turn smoothly then. While the hits change under a typed search, the
    // new ones just land, instead of the arc spinning with every result that comes in.
    property bool turning: false

    Timer {
        id: turnTimer
        interval: 450
        onTriggered: root.turning = false
    }

    function animateTurn() {
        turning = true;
        turnTimer.restart();
    }

    // Typing and clearing. Going from no text to some, or back, turns the rings.
    function setQuery(text) {
        if ((text.trim() !== "") !== searching) animateTurn();
        query = text;
    }

    // The screen the dial is open on. Only that screen's DialWindow shows it.
    property string screenName: ""

    // One of the shell's screens: `name` when the shell is on it, else the active window's,
    // else the first
    function screenFor(name) {
        let screens = ScreenService.targetScreens;
        let names = [];
        for (let i = 0; i < screens.length; i++) names.push(screens[i].name);
        if (names.indexOf(name) >= 0) return name;
        if (names.indexOf(WindowService.activeScreen) >= 0) return WindowService.activeScreen;
        return names.length > 0 ? names[0] : "";
    }

    // Opens the dial on a screen (empty: the active window's), or closes it. `kind` picks a
    // ring entry to open on, such as "windows"; empty keeps the last one.
    function toggle(screen, kind) {
        if (open) {
            close();
            return;
        }
        screenName = screenFor(screen);
        let index = kind ? Logic.categoryIndex(kind) : -1;
        if (index >= 0) category = index;
        open = true;
    }

    function close() {
        open = false;
    }

    onOpenChanged: {
        if (open) {
            SettingsPagesService.load();
        } else {
            query = "";
            scope = 0;
        }
    }

    onQueryChanged: {
        scope = 0;
        // Not trimmedQuery: that binding may not have caught up with the change yet,
        // which sent Filehouse the text one keystroke behind and left the files "stale"
        let text = query.trim();
        if (text.length >= Logic.SEARCH_FILES_MIN && FileSearchService.available) FileSearchService.search(text, 150);
        else FileSearchService.clear();
    }

    // Installed apps in the shape dialLogic.js wants. The entries are kept for launching.
    readonly property var entries: DesktopEntries.applications ? DesktopEntries.applications.values : []
    readonly property var apps: entries.map(e => ({
        "id": e.id,
        "name": e.name,
        "genericName": e.genericName ? e.genericName : "",
        "icon": e.icon,
        "fallback": "application-x-executable",
        "kind": "app",
        "sub": Logic.groupOf(e.categories ? e.categories : []),
        "detail": "Application · " + Logic.groupOf(e.categories ? e.categories : []),
        "categories": e.categories ? e.categories : [],
        "entry": e
    }))

    // Open windows, as the dock launcher's window switcher lists them, in the shape of an app.
    // Only read while the dial is open.
    readonly property var windowItems: open ? DockService.windowItems().map(w => ({
        "id": w.id,
        "kind": "window",
        "name": w.name,
        "icon": w.icon,
        "fallback": "application-x-executable",
        "sub": w.genericName,
        "detail": w.genericName + " · " + w.name,
        "window": w.window
    })) : []

    // Ids of the apps with an open window, as { appId: true }. A window counts for the app
    // whose desktop entry the dock finds for it.
    readonly property var runningIds: {
        let ids = {};
        if (!open) return ids;
        DockService.getMergedWindows().forEach(w => {
            let entry = w.appId ? DockService.findDesktopEntry(w.appId) : null;
            if (entry) ids[entry.id] = true;
        });
        return ids;
    }

    function isRunning(item) {
        return !!item && item.kind === "app" && !!runningIds[item.id];
    }

    // Hits of each source, in the same shape as an app so the arc treats them alike
    readonly property var appHits: Logic.matchApps(apps, query, DockService.usageStats, pinnedIds, runningIds)
    readonly property var settingHits: trimmedQuery.length >= Logic.SEARCH_SETTINGS_MIN
        ? SettingsPagesService.search(trimmedQuery).map(p => ({
            "id": "setting:" + p.id,
            "kind": "setting",
            "name": p.name,
            "icon": p.icon,
            "fallback": "preferences-system",
            "sub": "System Settings",
            "detail": "System Settings › " + p.name + (p.comment ? " · " + p.comment : ""),
            "page": p
        })) : []

    // Files of the search that ran last. They stay until the next results come in, so the
    // arc does not empty and refill on every keystroke.
    property var shownFiles: []
    // The files shown belong to what is typed now
    readonly property bool filesFresh: FileSearchService.query === trimmedQuery && !FileSearchService.hasPending && !FileSearchService.searching

    function syncFiles() {
        if (trimmedQuery.length < Logic.SEARCH_FILES_MIN) shownFiles = [];
        else if (FileSearchService.results.length > 0 || !FileSearchService.searching) shownFiles = FileSearchService.results;
    }
    onTrimmedQueryChanged: syncFiles()

    Connections {
        target: FileSearchService
        function onResultsChanged() { root.syncFiles(); }
        function onSearchingChanged() { root.syncFiles(); }
    }

    readonly property var fileHits: shownFiles.map(f => ({
        "id": "file:" + f.path,
        "kind": "file",
        "name": f.name,
        "icon": LauncherExtras.fileIconName(f),
        "fallback": f.dir ? "folder" : "text-x-generic",
        "sub": LauncherExtras.shortFolder(f.folder, Quickshell.env("HOME") || ""),
        "detail": f.path,
        "path": f.path,
        "folder": f.folder
    }))

    // What the ring shows: the categories, or the scopes while searching
    readonly property var ringLabels: searching
        ? Logic.scopeLabels(appHits, settingHits, fileHits)
        : Logic.CATEGORIES.map(c => c.name)
    readonly property int ringIndex: searching ? scope : category
    // Kind of the category shown ("pinned", "windows", "group", ...)
    readonly property string categoryKind: Logic.CATEGORIES[category].kind


    // Pinned app ids in pin order. The dial keeps its own pins in dial_pinned.json (gitignored),
    // apart from the dock's. They are ids, so a pin outlives an uninstalled app (it just does not show).
    property var pinnedIds: []

    FileView {
        id: pinFile
        path: Quickshell.shellDir + "/dial_pinned.json"
        printErrors: false
        onLoaded: {
            try {
                let parsed = JSON.parse(text());
                if (Array.isArray(parsed)) root.pinnedIds = parsed.filter(id => typeof id === "string");
            } catch (e) {
                console.warn("[DialService] Error parsing dial_pinned.json: " + e);
            }
        }
    }

    function isPinned(item) {
        return !!item && pinnedIds.indexOf(item.id) >= 0;
    }

    function togglePin(item) {
        if (!item || item.kind !== "app") return;
        pinnedIds = isPinned(item) ? pinnedIds.filter(id => id !== item.id) : pinnedIds.concat([item.id]);
        pinFile.setText(JSON.stringify(pinnedIds, null, 2));
    }

    // Launch history is the dock launcher's, so Recent and Frequent match it
    readonly property var items: searching
        ? Logic.arrange(Logic.scopeHits(scope, query, appHits, settingHits, fileHits))
        : Logic.itemsFor(category, apps, pinnedIds, DockService.usageStats, windowItems)

    // Where app positions are remembered: per category, or per scope and text while searching
    readonly property string focusKey: searching ? "?" + scope + ":" + trimmedQuery : String(category)

    readonly property int focusIndex: {
        let remembered = focusMemory[focusKey];
        if (items.length === 0) return 0;
        return Logic.clamp(remembered !== undefined ? remembered : Logic.middle(items.length), 0, items.length - 1);
    }

    function setCategory(index) {
        animateTurn();
        category = Logic.clamp(index, 0, Logic.CATEGORIES.length - 1);
    }

    // The ring's selection: a category, or a scope while searching
    function setRing(index) {
        animateTurn();
        if (searching) scope = Logic.clamp(index, 0, Logic.SCOPES.length - 1);
        else setCategory(index);
    }

    function setFocus(index) {
        animateTurn();
        let next = Object.assign({}, focusMemory);
        next[focusKey] = Logic.clamp(index, 0, Math.max(0, items.length - 1));
        focusMemory = next;
    }

    // The launch in progress, for the icon that flies to the pill: { name, icon, x, y, phase }.
    // x and y are where the tile sat in window coordinates; phase 1 means flying, 2 fading out.
    property var launching: null

    Timer {
        id: flyTimer
        interval: 40
        onTriggered: {
            if (root.launching) root.launching = Object.assign({}, root.launching, { "phase": 1 });
            root.open = false;
            clearTimer.restart();
        }
    }

    Timer {
        id: clearTimer
        interval: 2000
        onTriggered: {
            // Fade out first (phase 2), and drop the window only once that frame is empty.
            // Unmapping with the icon and pill still drawn made KWin play its close effect on them.
            root.launching = Object.assign({}, root.launching, { "phase": 2 });
            dropTimer.restart();
        }
    }

    Timer {
        id: dropTimer
        interval: 300
        onTriggered: root.launching = null
    }

    // An app item in the shape DockService's window matching and actions take
    function dockApp(item) {
        return { "id": item.id, "desktopFile": item.id + ".desktop", "name": item.name, "command": "" };
    }

    // Brings up a window of a running app: the next one after the active window, else the
    // first. False when no window matches after all.
    function switchTo(item) {
        let wins = DockService.findToplevels(dockApp(item));
        if (wins.length === 0) return false;
        let active = wins.findIndex(w => w.activated);
        DockService.activateWindow(wins[active >= 0 ? (active + 1) % wins.length : 0]);
        return true;
    }

    // Opens what a tile holds: switches to a window, or to a running app's window, and
    // starts anything else
    function launch(item, x, y) {
        if (!item) return;
        if (item.kind === "window") {
            DockService.activateWindow(item.window);
            close();
        } else if (isRunning(item) && switchTo(item)) {
            DockService.recordUse({ "id": item.id });
            close();
        } else {
            start(item, x, y);
        }
    }

    // What the tile's right-click menu offers, as [{ name, icon, run, closes }], with
    // { separator: true } between groups. `closes` closes the dial after `run`; launches close
    // it themselves. x and y are where the tile sits, for the launch animation.
    function menuFor(item, x, y) {
        if (!item) return [];
        let entries = [];
        let add = (name, icon, run, closes) => entries.push({ "name": name, "icon": icon, "run": run, "closes": !!closes });
        let separate = () => {
            if (entries.length > 0 && !entries[entries.length - 1].separator) entries.push({ "separator": true });
        };
        if (item.kind === "app") {
            let running = isRunning(item);
            if (running) {
                add("Switch To", "window", () => launch(item, x, y));
                add("New Window", "plus", () => start(item, x, y));
            } else {
                add("Open", "chevron-right", () => start(item, x, y));
            }
            let taken = entries.map(e => e.name.toLowerCase());
            let actions = DockService.getActionsForApp(dockApp(item)).filter(a => taken.indexOf(a.name.toLowerCase()) < 0);
            if (actions.length > 0) separate();
            actions.forEach(a => add(a.name, a.icon, a.execute, true));
            separate();
            add(isPinned(item) ? "Unpin from Dial" : "Pin to Dial", "pin", () => togglePin(item));
            add("Edit Application…", "settings", () => DockService.openMenuEditor(item.id + ".desktop"), true);
            if (running) add("Quit", "close", () => DockService.quitApp(dockApp(item)));
        } else if (item.kind === "window") {
            add("Switch To", "window", () => launch(item, x, y));
            add("Close Window", "close", () => DockService.closeWindow(item.window));
        } else if (item.kind === "file") {
            add("Open", "chevron-right", () => launch(item, x, y));
            if (item.folder) add("Open Containing Folder", "folder", () => Qt.openUrlExternally(LauncherExtras.fileUrl(item.folder)), true);
        } else if (item.kind === "setting") {
            add("Open", "settings", () => launch(item, x, y));
        }
        return entries;
    }

    // Runs the entry from where its tile sits. Terminal apps are wrapped in Konsole,
    // because DesktopEntry.execute() ignores runInTerminal.
    function start(item, x, y) {
        if (!item) return;
        if (item.kind === "app") {
            let entry = item.entry;
            DockService.recordUse({ "id": item.id });
            if (entry.runInTerminal && entry.command && entry.command.length > 0)
                WindowService.launchCommand(["konsole", "-e"].concat(entry.command), entry.id, entry.workingDirectory);
            else
                WindowService.launchEntry(entry);
        } else if (item.kind === "setting") {
            SettingsPagesService.open(item.page);
        } else if (item.kind === "file") {
            // Results of an earlier text are shown but not opened
            if (!filesFresh) return;
            Qt.openUrlExternally(LauncherExtras.fileUrl(item.path));
        } else {
            return;
        }
        dropTimer.stop();
        clearTimer.stop();
        launching = { "name": item.name, "icon": item.icon, "fallback": item.fallback, "x": x, "y": y, "phase": 0 };
        flyTimer.restart();
    }
}
