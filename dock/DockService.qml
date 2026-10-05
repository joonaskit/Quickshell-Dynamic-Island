pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

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
    property var appCategoriesMap: ({})

    // Process to scan desktop entry categories
    Process {
        id: categoriesScanProc
        command: ["python3", "-c", "import glob, os, json\ndef cat_group(cats):\n    s = set(cats)\n    if s & {'WebBrowser', 'Email', 'Network', 'Chat', 'IRCClient', 'Feed', 'FileTransfer'}: return 'Internet'\n    if s & {'Development', 'IDE', 'Debugger', 'GUIDesigner', 'Profiling', 'RevisionControl', 'Translation'}: return 'Development'\n    if s & {'AudioVideo', 'Audio', 'Video', 'Player', 'Recorder', 'Music', 'Midi'}: return 'Multimedia'\n    if s & {'Graphics', '2DGraphics', 'VectorGraphics', 'RasterGraphics', 'Photography', 'Viewer'}: return 'Graphics'\n    if s & {'Office', 'WordProcessor', 'Spreadsheet', 'Presentation', 'ContactManagement', 'Calendar'}: return 'Office'\n    if s & {'Game', 'ActionGame', 'ArcadeGame', 'BoardGame', 'CardGame', 'Emulator'}: return 'Games'\n    if s & {'System', 'Monitor', 'Security', 'TerminalEmulator', 'FileManager'}: return 'System'\n    if s & {'Utility', 'Settings', 'Accessibility', 'Archiving', 'Calculator', 'Clock', 'TextEditor'}: return 'Utilities'\n    return 'Utilities'\nres = {}\nfor d in ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]:\n    for f in glob.glob(d + '/**/*.desktop', recursive=True):\n        bn = os.path.basename(f)\n        try:\n            with open(f, 'r', errors='ignore') as fp:\n                for line in fp:\n                    if line.startswith('Categories='):\n                        raw = [c.strip() for c in line.split('=', 1)[1].split(';') if c.strip()]\n                        res[bn] = cat_group(raw)\n                        break\n        except: pass\nprint(json.dumps(res))"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let t = text.trim();
                if (t.length > 0) {
                    try {
                        root.appCategoriesMap = JSON.parse(t);
                        root.updateInstalledApps();
                    } catch(e) {}
                }
            }
        }
    }

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

    // Open KDE Menu Editor (kmenuedit) - optionally targeting a specific desktop file
    function openMenuEditor(desktopFile) {
        let entry = DesktopEntries.byId("org.kde.kmenuedit");
        if (!entry) entry = DesktopEntries.heuristicLookup("kmenuedit");
        if (entry) {
            try {
                entry.execute();
                return;
            } catch(e) {}
        }
        if (desktopFile && desktopFile.length > 0) {
            let df = desktopFile.endsWith(".desktop") ? desktopFile : (desktopFile + ".desktop");
            Quickshell.execDetached(["kmenuedit", df]);
        } else {
            Quickshell.execDetached(["kmenuedit"]);
        }
    }

    // Open KDE Application properties dialog (kioclient openProperties / kmenuedit)
    function openAppProperties(desktopFile) {
        if (!desktopFile || desktopFile.length === 0) {
            openMenuEditor();
            return;
        }

        let pyScript =
            "import os, sys, subprocess\n" +
            "def find_file(df):\n" +
            "    clean = df[:-8] if df.endswith('.desktop') else df\n" +
            "    search_dirs = [os.path.expanduser('~/.local/share/applications'), '/usr/share/applications', '/usr/local/share/applications']\n" +
            "    candidates = [df if df.endswith('.desktop') else (df + '.desktop'), clean + '.desktop', clean + '-stable.desktop']\n" +
            "    for d in search_dirs:\n" +
            "        for cand in candidates:\n" +
            "            p = os.path.join(d, cand)\n" +
            "            if os.path.exists(p): return p\n" +
            "    clean_lower = clean.lower()\n" +
            "    for d in search_dirs:\n" +
            "        if not os.path.exists(d): continue\n" +
            "        try:\n" +
            "            for f in os.listdir(d):\n" +
            "                if not f.endswith('.desktop'): continue\n" +
            "                base = f[:-8].lower()\n" +
            "                if clean_lower in base.split('.') or base == clean_lower:\n" +
            "                    return os.path.join(d, f)\n" +
            "        except Exception: pass\n" +
            "    return ''\n" +
            "arg = sys.argv[1] if len(sys.argv) > 1 else ''\n" +
            "target = find_file(arg)\n" +
            "if target:\n" +
            "    try:\n" +
            "        subprocess.Popen(['kioclient', 'openProperties', target])\n" +
            "        sys.exit(0)\n" +
            "    except Exception: pass\n" +
            "base_name = os.path.basename(target) if target else (arg if arg.endswith('.desktop') else (arg + '.desktop'))\n" +
            "try:\n" +
            "    subprocess.Popen(['kmenuedit', base_name])\n" +
            "except Exception:\n" +
            "    subprocess.Popen(['kmenuedit'])\n";

        Quickshell.execDetached(["python3", "-c", pyScript, String(desktopFile)]);
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
                    rawAppId: w.rawApp || "",
                    gameName: w.rawApp ? (w.name || "") : "",
                    gameIcon: w.rawApp ? (w.icon || "") : "",
                    gameCommand: w.rawApp ? (w.command || "") : "",
                    isKWin: true
                });
            }
        }
        if (ToplevelManager.toplevels && ToplevelManager.toplevels.values && ToplevelManager.toplevels.values.length > 0) {
            for (let j = 0; j < ToplevelManager.toplevels.values.length; j++) {
                let tw = ToplevelManager.toplevels.values[j];
                let dup = false;
                for (let k = 0; k < list.length; k++) {
                    let kw = list[k];
                    if (kw.isKWin && kw.gameName && kw.rawAppId === tw.appId && kw.title === tw.title) { dup = true; break; }
                }
                if (dup) continue;
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
        let rawLower = (app.rawAppId || "").toLowerCase().replace(/\.desktop$/, "");
        let cmdLower = (app.command || "").toLowerCase();
        let nameLower = (app.name || "").toLowerCase();

        // Entries declaring StartupWMClass are matched exactly, so that e.g. a
        // Vivaldi PWA window is not mistaken for the Vivaldi browser itself.
        let entry = findDesktopEntry(app.desktopFile || app.id || "");
        let wmClass = ((entry && entry.startupClass) || "").toLowerCase();
        let strict = wmClass.length > 0;

        for (let i = 0; i < wins.length; i++) {
            let w = wins[i];
            if (!w || !w.appId) continue;
            let wApp = w.appId.toLowerCase().replace(/\.desktop$/, "");

            let match = (wApp === idLower || wApp === deskLower || (rawLower.length > 0 && wApp === rawLower) || (strict && wApp === wmClass));
            if (strict) {
                if (match) list.push(w);
                continue;
            }
            if (!match && idLower.length > 2 && (wApp.endsWith("." + idLower) || deskLower.endsWith("." + wApp) || idLower.indexOf(wApp) >= 0 || wApp.indexOf(idLower) >= 0)) {
                match = true;
            }
            if (!match && rawLower.length > 2 && (wApp.endsWith("." + rawLower) || rawLower.indexOf(wApp) >= 0 || wApp.indexOf(rawLower) >= 0)) {
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

    // Find active MPRIS media player associated with an application
    function getMprisPlayerForApp(app) {
        if (!app || !Mpris.players || !Mpris.players.values) return null;
        let players = Mpris.players.values;
        let appId = (app.id || "").toLowerCase().replace(/\.desktop$/, "");
        let appName = (app.name || "").toLowerCase();
        let appCmd = (app.command || "").toLowerCase();
        let desktopFile = (app.desktopFile || "").toLowerCase().replace(/\.desktop$/, "");

        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (!p) continue;
            let pEntry = (p.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
            let pIdent = (p.identity || "").toLowerCase();
            let pBus = (p.dbusName || "").toLowerCase();

            // Match desktop entry
            if (pEntry && (pEntry === appId || pEntry === desktopFile || appId.indexOf(pEntry) >= 0 || desktopFile.indexOf(pEntry) >= 0 || pEntry.indexOf(appId) >= 0)) {
                return p;
            }
            // Match identity / name
            if (pIdent && (pIdent === appName || appName.indexOf(pIdent) >= 0 || pIdent.indexOf(appName) >= 0)) {
                return p;
            }
            // Match dbus name
            if (pBus && ((appId && pBus.indexOf(appId) >= 0) || (appCmd && pBus.indexOf(appCmd) >= 0))) {
                return p;
            }
        }
        return null;
    }

    // Get contextual actions for an application (native desktop actions & app-specific shortcuts)
    function getActionsForApp(app) {
        if (!app) return [];
        let actions = [];
        let addedNames = {};

        function addAction(name, icon, execFn) {
            let key = (name || "").toLowerCase().trim();
            if (key.length === 0 || addedNames[key]) return;
            addedNames[key] = true;
            actions.push({
                name: name,
                icon: icon || "chevron-right",
                execute: execFn
            });
        }

        // 1. Native DesktopEntry actions
        let entry = null;
        if (app.desktopFile) {
            let cleanId = app.desktopFile.replace(/\.desktop$/, "");
            entry = DesktopEntries.byId(cleanId);
            if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
        }
        if (!entry && app.id) {
            let cleanId2 = app.id.replace(/\.desktop$/, "");
            entry = DesktopEntries.byId(cleanId2);
            if (!entry) entry = DesktopEntries.heuristicLookup(cleanId2);
        }

        if (entry && entry.actions) {
            let acts = entry.actions;
            for (let i = 0; i < acts.length; i++) {
                let act = acts[i];
                if (!act || !act.name) continue;
                let nLow = act.name.toLowerCase();
                let icon = "chevron-right";
                if (nLow.indexOf("private") >= 0 || nLow.indexOf("incognito") >= 0 || nLow.indexOf("secret") >= 0 || nLow.indexOf("window") >= 0 || nLow.indexOf("workspace") >= 0) {
                    icon = "window";
                } else if (nLow.indexOf("tab") >= 0 || nLow.indexOf("new") >= 0 || nLow.indexOf("add") >= 0 || nLow.indexOf("compose") >= 0) {
                    icon = "plus";
                } else if (nLow.indexOf("terminal") >= 0 || nLow.indexOf("shell") >= 0) {
                    icon = "terminal";
                } else if (nLow.indexOf("folder") >= 0 || nLow.indexOf("document") >= 0 || nLow.indexOf("directory") >= 0) {
                    icon = "folder";
                } else if (nLow.indexOf("setting") >= 0 || nLow.indexOf("pref") >= 0) {
                    icon = "settings";
                } else if (nLow.indexOf("search") >= 0 || nLow.indexOf("find") >= 0) {
                    icon = "search";
                }

                (function(actionObj) {
                    addAction(actionObj.name, icon, function() {
                        try {
                            actionObj.execute();
                        } catch(e) {
                            console.warn("[DockService] Error executing action:", e);
                        }
                    });
                })(act);
            }
        }

        // 2. Custom app-specific shortcuts
        let idLow = (app.id || "").toLowerCase();
        let nameLow = (app.name || "").toLowerCase();
        let homeDir = Quickshell.env("HOME") || "";

        // File Managers (Dolphin, Nautilus, etc.)
        let isFileManager = idLow.indexOf("dolphin") >= 0 || idLow.indexOf("nautilus") >= 0 ||
                            idLow.indexOf("thunar") >= 0 || idLow.indexOf("nemo") >= 0 ||
                            idLow.indexOf("pcmanfm") >= 0 || nameLow === "files" || nameLow.indexOf("file manager") >= 0;

        if (isFileManager && homeDir) {
            addAction("Home", "folder", function() {
                Quickshell.execDetached(["xdg-open", homeDir]);
            });
            addAction("Downloads", "folder", function() {
                Quickshell.execDetached(["xdg-open", homeDir + "/Downloads"]);
            });
            addAction("Documents", "folder", function() {
                Quickshell.execDetached(["xdg-open", homeDir + "/Documents"]);
            });
        }

        // Web Browsers (Firefox, Chrome, Brave, Chromium, Zen, Vivaldi, etc.)
        let isBrowser = idLow.indexOf("firefox") >= 0 || idLow.indexOf("chrome") >= 0 ||
                        idLow.indexOf("brave") >= 0 || idLow.indexOf("chromium") >= 0 ||
                        idLow.indexOf("zen") >= 0 || idLow.indexOf("vivaldi") >= 0;

        if (isBrowser) {
            let hasPrivate = false;
            for (let k = 0; k < actions.length; k++) {
                let ak = actions[k].name.toLowerCase();
                if (ak.indexOf("private") >= 0 || ak.indexOf("incognito") >= 0) {
                    hasPrivate = true;
                    break;
                }
            }
            if (!hasPrivate) {
                if (idLow.indexOf("firefox") >= 0 || idLow.indexOf("zen") >= 0) {
                    addAction("New Private Window", "window", function() {
                        Quickshell.execDetached([app.command || "firefox", "--private-window"]);
                    });
                } else {
                    addAction("New Incognito Window", "window", function() {
                        Quickshell.execDetached([app.command || "google-chrome", "--incognito"]);
                    });
                }
            }
        }

        // Terminal Emulators
        let isTerminal = idLow.indexOf("terminal") >= 0 || idLow.indexOf("konsole") >= 0 ||
                         idLow.indexOf("kitty") >= 0 || idLow.indexOf("alacritty") >= 0 ||
                         idLow.indexOf("foot") >= 0 || idLow.indexOf("wezterm") >= 0;

        if (isTerminal && actions.length === 0) {
            addAction("New Window", "terminal", function() {
                if (app.command) {
                    Quickshell.execDetached(["sh", "-c", app.command]);
                } else {
                    launchApp(app);
                }
            });
        }

        // Code editors
        let isEditor = idLow.indexOf("code") >= 0 || idLow.indexOf("zed") >= 0;
        if (isEditor && actions.length === 0) {
            if (idLow.indexOf("code") >= 0) {
                addAction("New Empty Window", "window", function() {
                    Quickshell.execDetached(["code", "--new-window"]);
                });
            } else if (idLow.indexOf("zed") >= 0) {
                addAction("New Workspace", "window", function() {
                    Quickshell.execDetached(["zed", "--new"]);
                });
            }
        }

        return actions;
    }


    // Helper to resolve desktop entry across various naming patterns (e.g. vivaldi vs vivaldi-stable)
    function findDesktopEntry(appId) {
        if (!appId) return null;
        let clean = appId.replace(/\.desktop$/, "");
        let entry = DesktopEntries.byId(clean);
        if (!entry) entry = DesktopEntries.heuristicLookup(clean);
        if (!entry && clean.endsWith("-stable")) entry = DesktopEntries.byId(clean.replace(/-stable$/, ""));
        if (!entry) entry = DesktopEntries.byId(clean + "-stable");
        if (!entry && DesktopEntries.applications && DesktopEntries.applications.values) {
            let vals = DesktopEntries.applications.values;
            let cLow = clean.toLowerCase();
            for (let i = 0; i < vals.length; i++) {
                let e = vals[i];
                if (!e) continue;
                let eId = (e.id || "").toLowerCase();
                let eName = (e.name || "").toLowerCase();
                if (eId === cLow || eId.indexOf(cLow) >= 0 || cLow.indexOf(eId) >= 0 || eName === cLow) {
                    return e;
                }
            }
        }
        return entry;
    }

    // Launch app process
    function launchApp(app) {
        if (!app) return;

        // Try DesktopEntry lookup
        let targetId = app.desktopFile || app.id || "";
        let entry = findDesktopEntry(targetId);
        if (entry) {
            try {
                entry.execute();
                return;
            } catch(e) {
                console.warn("[DockService] Error executing desktop entry: " + e);
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
        let pinnedWinIds = {};

        // Track pinned apps status and index their open windows
        for (let i = 0; i < root.pinnedApps.length; i++) {
            let app = root.pinnedApps[i];
            let matchingWins = findToplevels(app);
            let count = matchingWins.length;
            let focused = matchingWins.some(function(w) { return w.activated; });
            newMap[app.id] = { running: count > 0, focused: focused, count: count };
            for (let m = 0; m < matchingWins.length; m++) {
                pinnedWinIds[matchingWins[m].id] = true;
            }
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

            // Check if this window already belongs to a pinned app
            let isAlreadyPinned = !!pinnedWinIds[w.id] || root.isPinned(appId);

            if (!isAlreadyPinned) {
                // Try to resolve desktop entry metadata
                let entry = w.gameName ? null : root.findDesktopEntry(appId);
                let effectiveId = entry ? entry.id : appId;
                let effectiveKey = effectiveId.toLowerCase().replace(/\.desktop$/, "");

                // Check again with effective desktop ID
                if (root.isPinned(effectiveId)) {
                    continue;
                }

                if (!unpinnedMap[effectiveKey]) {
                    let appName = entry ? entry.name : appId;
                    let iconName = entry ? entry.icon : appId;
                    let deskFile = entry ? (entry.id.endsWith(".desktop") ? entry.id : (entry.id + ".desktop")) : (appId.endsWith(".desktop") ? appId : (appId + ".desktop"));
                    let execCmd = entry ? (entry.execString || entry.command || appId) : appId;

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

                    if (w.gameName) {
                        appName = w.gameName;
                        if (w.gameIcon) iconName = w.gameIcon;
                        execCmd = w.gameCommand || "";
                    }

                    unpinnedMap[effectiveKey] = {
                        id: effectiveId,
                        rawAppId: appId,
                        name: appName,
                        icon: iconName,
                        desktopFile: deskFile,
                        command: execCmd,
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
            if (item.rawAppId && item.rawAppId !== item.id) {
                newMap[item.rawAppId] = newMap[item.id];
            }
            unpinnedList.push(item);
        }

        root.runningStateMap = newMap;
        root.runningUnpinnedApps = unpinnedList;
        root.stateUpdated();
    }

    function guessCategory(name, generic, comment) {
        let text = ((name || "") + " " + (generic || "") + " " + (comment || "")).toLowerCase();
        if (/browser|web|mail|chat|irc|torrent|download|sync|vpn/.test(text)) return "Internet";
        if (/code|develop|git|ide|debug|terminal|bash|shell|compiler/.test(text)) return "Development";
        if (/music|audio|video|player|mp3|movie|media|sound|recorder/.test(text)) return "Multimedia";
        if (/photo|image|draw|paint|vector|graphics|viewer|screenshot/.test(text)) return "Graphics";
        if (/calc|document|sheet|office|writer|pdf|word|slide/.test(text)) return "Office";
        if (/game|play|steam|arcade|craft/.test(text)) return "Games";
        if (/system|monitor|process|task|disk|partition|device/.test(text)) return "System";
        return "Utilities";
    }

    // Helper to populate installed applications list for App Picker
    function updateInstalledApps() {
        if (!DesktopEntries.applications || !DesktopEntries.applications.values) return;
        let raw = DesktopEntries.applications.values;
        let list = [];
        for (let i = 0; i < raw.length; i++) {
            let entry = raw[i];
            if (!entry || entry.noDisplay || !entry.name) continue;
            let desktopFile = entry.id.endsWith(".desktop") ? entry.id : (entry.id + ".desktop");
            let cat = root.appCategoriesMap[desktopFile] || root.appCategoriesMap[entry.id] || root.guessCategory(entry.name, entry.genericName, entry.comment);
            list.push({
                id: entry.id,
                name: entry.name,
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                icon: entry.icon || "application-x-executable",
                desktopFile: desktopFile,
                category: cat
            });
        }
        list.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        root.installedApps = list;
    }

    // Resolve an icon source string to a file URL or image://icon
    function resolveIcon(iconName) {
        if (!iconName || iconName.length === 0) return "";
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
