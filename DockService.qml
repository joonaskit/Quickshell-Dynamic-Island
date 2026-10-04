pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    // Pinned applications model
    property var pinnedApps: [
        {
            id: "dolphin",
            name: "Files",
            icon: "org.kde.dolphin",
            desktopFile: "org.kde.dolphin.desktop",
            command: "dolphin"
        },
        {
            id: "firefox",
            name: "Firefox",
            icon: "firefox",
            desktopFile: "org.mozilla.firefox.desktop",
            command: "firefox"
        },
        {
            id: "konsole",
            name: "Terminal",
            icon: "utilities-terminal",
            desktopFile: "org.kde.konsole.desktop",
            command: "konsole"
        },
        {
            id: "antigravity-ide",
            name: "Antigravity",
            icon: "/home/jkikke/Lataukset/Antigravity IDE/resources/app/resources/linux/code.png",
            desktopFile: "",
            command: "\"/home/jkikke/Lataukset/Antigravity IDE/antigravity-ide\""
        },
        {
            id: "zed",
            name: "Zed",
            icon: "dev.zed.Zed",
            desktopFile: "dev.zed.Zed.desktop",
            command: "zed"
        },
        {
            id: "systemmonitor",
            name: "Activity",
            icon: "utilities-system-monitor",
            desktopFile: "org.kde.plasma-systemmonitor.desktop",
            command: "plasma-systemmonitor"
        },
        {
            id: "systemsettings",
            name: "Settings",
            icon: "preferences-system",
            desktopFile: "systemsettings.desktop",
            command: "systemsettings"
        }
    ]

    // Running unpinned applications (dynamically discovered from open windows)
    property var runningUnpinnedApps: []

    // Cache of running state mapped by app key: { running: bool, focused: bool, count: int }
    property var runningStateMap: ({})

    // Trash state
    property int trashCount: 0

    // Full list of installed apps for App Picker
    property var installedApps: []

    // Signals
    signal stateUpdated()
    signal toggleAppLauncherRequested()

    Component.onCompleted: {
        loadPinnedApps();
        updateInstalledApps();
        updateRunningApps();
        checkTrash();
    }

    // Debounce timer for updating installed apps when desktop entries finish scanning
    Timer {
        id: appEntriesUpdateTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.updateInstalledApps();
            root.updateRunningApps();
        }
    }

    Connections {
        target: DesktopEntries.applications ? DesktopEntries.applications : null
        function onValuesChanged() {
            appEntriesUpdateTimer.restart();
        }
    }

    // Timer for keeping state updated
    Timer {
        id: refreshTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.updateRunningApps();
        }
    }

    // Trash monitor timer
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            root.checkTrash();
        }
    }

    Connections {
        target: ToplevelManager.toplevels ? ToplevelManager.toplevels : null
        function onValuesChanged() {
            root.updateRunningApps();
        }
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            root.updateRunningApps();
        }
    }

    // Process to check trash count
    Process {
        id: trashProc
        command: ["sh", "-c", "ls -1 ~/.local/share/Trash/files 2>/dev/null | wc -l"]
        stdout: SplitParser {
            onRead: function(line) {
                let n = parseInt(line.trim());
                if (!isNaN(n)) root.trashCount = n;
            }
        }
    }

    function checkTrash() {
        if (!trashProc.running) {
            trashProc.running = true;
        }
    }

    function openTrash() {
        Quickshell.execDetached(["dolphin", "trash:/"]);
    }

    function emptyTrash() {
        Quickshell.execDetached(["sh", "-c", "rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/*"]);
        checkTrashTimer.start();
    }

    Timer {
        id: checkTrashTimer
        interval: 400
        repeat: false
        onTriggered: root.checkTrash()
    }

    function openLaunchpad() {
        Quickshell.execDetached(["qdbus-qt6", "org.kde.krunner", "/App", "display"]);
    }

    // File loading/saving for pinned apps persistence
    readonly property string configFilePath: Quickshell.shellDir + "/dock_pinned.json"

    Process {
        id: loadPinnedProc
        command: ["python3", "-c", "import sys, os; p=sys.argv[1]; sys.stdout.write(open(p).read() if os.path.exists(p) else '')", root.configFilePath]
        running: true

        stdout: StdioCollector {
            onTextChanged: {
                let t = text.trim();
                if (t.length > 0) {
                    try {
                        let parsed = JSON.parse(t);
                        if (Array.isArray(parsed) && parsed.length > 0) {
                            root.pinnedApps = parsed;
                            root.updateRunningApps();
                        }
                    } catch(e) {
                        console.warn("[DockService] Error parsing dock_pinned.json: " + e);
                    }
                }
            }
        }
    }

    Process {
        id: savePinnedProc
        command: []
    }

    Timer {
        id: savePinnedDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            let jsonStr = JSON.stringify(root.pinnedApps, null, 2);
            savePinnedProc.command = ["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", root.configFilePath, jsonStr];
            savePinnedProc.running = true;
        }
    }

    function loadPinnedApps() {
        if (!loadPinnedProc.running) {
            loadPinnedProc.running = true;
        }
    }

    function savePinnedApps() {
        savePinnedDebounceTimer.restart();
    }

    // Reorder pinned applications
    function reorderPinnedApps(fromIndex, toIndex) {
        if (fromIndex === toIndex) return;
        if (fromIndex < 0 || fromIndex >= root.pinnedApps.length) return;
        if (toIndex < 0 || toIndex >= root.pinnedApps.length) return;

        let arr = root.pinnedApps.slice();
        let item = arr.splice(fromIndex, 1)[0];
        arr.splice(toIndex, 0, item);
        root.pinnedApps = arr;
        savePinnedApps();
        updateRunningApps();
    }

    // Pin an application
    function pinApp(app) {
        if (!app) return;
        let id = app.id || app.desktopFile || app.name;
        if (isPinned(id)) return;

        let newApp = {
            id: id,
            name: app.name || "App",
            icon: app.icon || "application-x-executable",
            desktopFile: app.desktopFile || (id.endsWith(".desktop") ? id : (id + ".desktop")),
            command: app.command || ""
        };

        let arr = root.pinnedApps.slice();
        arr.push(newApp);
        root.pinnedApps = arr;
        savePinnedApps();
        updateRunningApps();
    }

    // Unpin an application
    function unpinApp(id) {
        let arr = root.pinnedApps.filter(function(a) {
            return a.id !== id && a.desktopFile !== id;
        });
        root.pinnedApps = arr;
        savePinnedApps();
        updateRunningApps();
    }

    function isPinned(id) {
        if (!id) return false;
        let clean = id.toLowerCase().replace(/\.desktop$/, "");
        for (let i = 0; i < root.pinnedApps.length; i++) {
            let p = root.pinnedApps[i];
            let pId = (p.id || "").toLowerCase().replace(/\.desktop$/, "");
            let pDesk = (p.desktopFile || "").toLowerCase().replace(/\.desktop$/, "");
            if (pId === clean || pDesk === clean) return true;
        }
        return false;
    }

    Connections {
        target: WindowService
        function onWindowListChanged() {
            root.updateRunningApps();
        }
        function onActiveAppIdChanged() {
            root.updateRunningApps();
        }
    }

    // Get list of open windows from WindowService (KWin) and ToplevelManager (Wayland)
    function getMergedWindows() {
        let list = [];
        if (WindowService.windowList && WindowService.windowList.length > 0) {
            for (let i = 0; i < WindowService.windowList.length; i++) {
                let w = WindowService.windowList[i];
                list.push({
                    id: w.id,
                    appId: w.app,
                    title: w.title,
                    activated: !!w.active,
                    minimized: !!w.minimized,
                    isKWin: true
                });
            }
        }
        if (ToplevelManager.toplevels && ToplevelManager.toplevels.values && ToplevelManager.toplevels.values.length > 0) {
            for (let j = 0; j < ToplevelManager.toplevels.values.length; j++) {
                let tw = ToplevelManager.toplevels.values[j];
                list.push({
                    id: tw.appId,
                    appId: tw.appId,
                    title: tw.title,
                    activated: tw.activated,
                    minimized: tw.minimized,
                    raw: tw,
                    isKWin: false
                });
            }
        }
        return list;
    }

    // Match windows to an app definition
    function findToplevels(app) {
        let wins = getMergedWindows();
        if (wins.length === 0) return [];
        let list = [];
        let idLower = (app.id || "").toLowerCase().replace(/\.desktop$/, "");
        let deskLower = (app.desktopFile || "").toLowerCase().replace(/\.desktop$/, "");
        let cmdLower = (app.command || "").toLowerCase();
        let nameLower = (app.name || "").toLowerCase();

        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            if (!w || !w.appId) continue;
            let wApp = w.appId.toLowerCase().replace(/\.desktop$/, "");

            let match = (wApp === idLower || wApp === deskLower);
            if (!match && idLower.length > 2 && (wApp.endsWith("." + idLower) || deskLower.endsWith("." + wApp) || idLower.indexOf(wApp) >= 0 || wApp.indexOf(idLower) >= 0)) {
                match = true;
            }
            if (!match && cmdLower.length > 2 && (wApp === cmdLower || wApp.indexOf(cmdLower) >= 0 || cmdLower.indexOf(wApp) >= 0)) {
                match = true;
            }
            if (!match && nameLower.length > 3 && wApp.indexOf(nameLower) >= 0) {
                match = true;
            }

            if (match) {
                list.push(w);
            }
        }
        return list;
    }

    // Check if an app is running
    function isRunning(app) {
        let wins = findToplevels(app);
        return wins.length > 0;
    }

    // Check if an app has focus
    function isFocused(app) {
        let wins = findToplevels(app);
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].activated) return true;
        }
        return false;
    }

    // Get count of open windows
    function getWindowCount(app) {
        return findToplevels(app).length;
    }

    // Activate or launch application
    function activateOrLaunch(app) {
        let wins = findToplevels(app);
        if (wins.length > 0) {
            let activeIdx = -1;
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].activated) {
                    activeIdx = i;
                    break;
                }
            }

            if (activeIdx >= 0) {
                if (wins.length === 1) {
                    // Minimize if only 1 active window
                    let w = wins[0];
                    if (w.isKWin) {
                        WindowService.activateWindow(w.id);
                    } else if (w.raw) {
                        w.raw.minimized = true;
                    }
                } else {
                    // Cycle to next window
                    let nextIdx = (activeIdx + 1) % wins.length;
                    let nw = wins[nextIdx];
                    if (nw.isKWin) {
                        WindowService.activateWindow(nw.id);
                    } else if (nw.raw) {
                        if (nw.raw.minimized) nw.raw.minimized = false;
                        nw.raw.activate();
                    }
                }
            } else {
                // Focus first window
                let fw = wins[0];
                if (fw.isKWin) {
                    WindowService.activateWindow(fw.id);
                } else if (fw.raw) {
                    if (fw.raw.minimized) fw.raw.minimized = false;
                    fw.raw.activate();
                }
            }
        } else {
            launchApp(app);
        }
    }

    // Launch a new window/instance
    function newWindow(app) {
        launchApp(app);
    }

    // Quit an application
    function quitApp(app) {
        let wins = findToplevels(app);
        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            if (w.isKWin) {
                WindowService.closeWindow(w.id);
            } else if (w.raw) {
                try { w.raw.close(); } catch(e) {}
            }
        }
    }

    // Launch app process
    function launchApp(app) {
        if (!app) return;

        // Try DesktopEntry lookup
        if (app.desktopFile) {
            let cleanId = app.desktopFile.replace(/\.desktop$/, "");
            let entry = DesktopEntries.byId(cleanId);
            if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
            if (entry) {
                entry.execute();
                return;
            }
        }

        // Try gtk-launch
        if (app.desktopFile) {
            Quickshell.execDetached(["gtk-launch", app.desktopFile]);
            return;
        }

        // Try command
        if (app.command) {
            Quickshell.execDetached(["sh", "-c", app.command]);
        }
    }

    // Update running states & discover running unpinned apps
    function updateRunningApps() {
        let wins = getMergedWindows();

        let newMap = {};
        let unpinnedMap = {};

        // Track pinned apps status
        for (let i = 0; i < root.pinnedApps.length; i++) {
            let app = root.pinnedApps[i];
            let matchingWins = findToplevels(app);
            let count = matchingWins.length;
            let focused = matchingWins.some(function(w) { return w.activated; });
            newMap[app.id] = { running: count > 0, focused: focused, count: count };
        }

        let ignoreList = ["xwaylandvideobridge", "quickshell", "plasmashell", "kded", "krunner", "polkit", "kaccess", "plasmawindowed"];

        // Find unpinned apps from all running toplevels
        for (let j = 0; j < wins.length; j++) {
            let w = wins[j];
            if (!w || !w.appId) continue;
            let appId = w.appId;
            let aLow = appId.toLowerCase();
            if (ignoreList.some(function(ig) { return aLow.indexOf(ig) >= 0; })) {
                continue;
            }

            let isAlreadyPinned = false;

            for (let k = 0; k < root.pinnedApps.length; k++) {
                let p = root.pinnedApps[k];
                let pToplevels = findToplevels(p);
                if (pToplevels.some(function(tw) { return tw.id === w.id || (tw.appId === w.appId && tw.title === w.title); })) {
                    isAlreadyPinned = true;
                    break;
                }
            }

            if (!isAlreadyPinned) {
                let key = appId.toLowerCase();
                if (!unpinnedMap[key]) {
                    // Try to resolve desktop entry metadata
                    let entry = DesktopEntries.byId(appId.replace(/\.desktop$/, ""));
                    if (!entry) entry = DesktopEntries.heuristicLookup(appId);

                    let appName = entry ? entry.name : appId;
                    let iconName = entry ? entry.icon : appId;

                    // Clean formatted app name if fallback
                    if (!entry) {
                        let segs = appId.split(".");
                        let last = segs[segs.length - 1];
                        if (last.toLowerCase() === "desktop" && segs.length > 1) {
                            last = segs[segs.length - 2];
                        }
                        if (last.length > 0) {
                            appName = last.charAt(0).toUpperCase() + last.slice(1);
                        }
                    }

                    unpinnedMap[key] = {
                        id: appId,
                        name: appName,
                        icon: iconName,
                        desktopFile: appId.endsWith(".desktop") ? appId : (appId + ".desktop"),
                        command: appId,
                        isUnpinned: true
                    };
                }
            }
        }

        let unpinnedList = [];
        for (let k in unpinnedMap) {
            let item = unpinnedMap[k];
            let matchingWins = findToplevels(item);
            let count = matchingWins.length;
            let focused = matchingWins.some(function(w) { return w.activated; });
            newMap[item.id] = { running: count > 0, focused: focused, count: count };
            unpinnedList.push(item);
        }

        root.runningStateMap = newMap;
        root.runningUnpinnedApps = unpinnedList;
        root.stateUpdated();
    }

    // Helper to populate installed applications list for App Picker
    function updateInstalledApps() {
        if (!DesktopEntries.applications || !DesktopEntries.applications.values) return;
        let raw = DesktopEntries.applications.values;
        let list = [];
        for (let i = 0; i < raw.length; i++) {
            let entry = raw[i];
            if (!entry || entry.noDisplay || !entry.name) continue;
            list.push({
                id: entry.id,
                name: entry.name,
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                icon: entry.icon || "application-x-executable",
                desktopFile: entry.id.endsWith(".desktop") ? entry.id : (entry.id + ".desktop")
            });
        }
        list.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        root.installedApps = list;
        Quickshell.execDetached(["bash", "-c", "echo 'installedApps length=" + list.length + "' >> /tmp/qs_dock_debug.log"]);
    }

    // Resolve an icon source string to a file URL or image://icon
    function resolveIcon(iconName) {
        if (!iconName || iconName.length === 0) return "";
        if (iconName.toLowerCase().indexOf("antigravity") >= 0) {
            return "file:///home/jkikke/Lataukset/Antigravity IDE/resources/app/resources/linux/code.png";
        }
        if (iconName.startsWith("file://") || iconName.startsWith("image://")) {
            return iconName;
        }
        if (iconName.startsWith("/")) {
            return "file://" + iconName;
        }
        if (Quickshell.hasThemeIcon(iconName)) {
            return "image://icon/" + iconName;
        }
        let p = Quickshell.iconPath(iconName);
        if (p && p.length > 0) {
            if (p.startsWith("file://") || p.startsWith("image://")) {
                return p;
            }
            if (p.startsWith("/")) {
                return "file://" + p;
            }
        }
        return "";
    }
}
