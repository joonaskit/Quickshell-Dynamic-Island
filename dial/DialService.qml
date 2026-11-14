pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "dialLogic.js" as Logic
import "dialPages.js" as Pages
import "../services/clipboardHistory.js" as ClipboardHistory
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

    // The status page shown in place of the launcher (Logic.pageFor), or "" for the launcher
    property string page: ""

    // Opens a page, or goes back to the launcher when it is already open
    function togglePage(next) {
        animateTurn();
        armedAction = "";
        passwordFor = "";
        query = "";
        // A page starts on its own slot each time (Logic.pageFocus): its lists change
        let memory = Object.assign({}, focusMemory);
        delete memory["page:" + next];
        focusMemory = memory;
        notificationApp = "";
        clipboardFilter = 0;
        page = page === next ? "" : next;
    }

    // The Hue page goes back to the favourite lamp each time it closes, as its card does
    onPageChanged: if (page !== "hue") HueService.viewedId = ""

    // The app the notification page's ring is on ("" for all), and the clipboard page's
    // filter (index into Pages.CLIPBOARD_FILTERS)
    property string notificationApp: ""
    property int clipboardFilter: 0

    // A tile asks for a sheet (DialSheet) by its icon's id; DialWindow shows it over the disc
    signal cardRequested(string id)

    // The clipboard history under the page's filter, in the shape Pages.clipboardItems takes
    readonly property var clipboardEntries: page !== "clipboard" ? []
        : ClipboardHistory.view(ClipboardService.history, "", Pages.CLIPBOARD_FILTERS[clipboardFilter]).map(e => ({
            "id": e.id,
            "kind": e.kind,
            "pinned": e.pinned,
            "sensitive": e.sensitive,
            "label": ClipboardHistory.label(e, 40),
            "age": ClipboardHistory.formatAge(e.time, Date.now())
        }))

    // The hardware page's ring selection (Logic.HARDWARE_RING)
    property int hardwareMetric: 0

    // Programs are only sampled while the hardware page is open
    Binding {
        target: HardwareStatsService
        property: "watchProcesses"
        value: root.open && root.page === "hardware"
    }

    // A program's tile under its app's name and icon, when a desktop entry matches it
    function withApp(item) {
        let entry = DesktopEntries.heuristicLookup(item.process);
        if (!entry) return item;
        return Object.assign({}, item, { "name": entry.name, "icon": entry.icon });
    }

    // Power profiles only show when power-profiles-daemon is there
    readonly property bool profilesAvailable: !DepsService.iconUnavailable("profile")

    // The network the Wi-Fi page asks a password for, or ""
    property string passwordFor: ""

    function submitPassword(password) {
        if (passwordFor === "" || password === "") return;
        NetworkService.connectTo(passwordFor, password);
        passwordFor = "";
    }

    // Sets the page's slider (the gauge, on pages that have one) to `level`, 0 to 1. Raising
    // the input level unmutes the microphone, as the card's slider does.
    function setSlider(level) {
        if (page === "mic") {
            MicrophoneService.setVolume(level);
            if (level > 0 && MicrophoneService.isMuted) MicrophoneService.setMute(false);
        } else if (page === "nightLight") {
            // Shown at once, and saved when the slider has been still for a moment: saving
            // reloads KWin's Night Light plugin
            NightLightService.previewTemperature(Pages.kelvinAt(level, NightLightService.minTemperature, NightLightService.maxTemperature));
            nightCommit.restart();
        } else if (page === "hue") {
            let light = HueService.selectedLight;
            if (light) HueService.setBrightness(light.id, level * 100);
        }
    }

    Timer {
        id: nightCommit
        interval: 500
        onTriggered: NightLightService.commitTemperature(NightLightService.nightTemperature)
    }

    // Runs a tile of the dialPages.js pages. False when the tile is not one of theirs.
    function pageAction(item) {
        let id = item.id;
        let light = HueService.selectedLight;
        let phone = KdeConnectService.device;
        if (item.nightMode) NightLightService.setMode(item.nightMode);
        else if (id === "huePower") { if (light) HueService.toggle(light.id); }
        else if (id === "hueFavourite") { if (light) HueService.toggleFavourite(light.id); }
        else if (item.mirek) { if (light) HueService.setMirek(light.id, item.mirek); }
        else if (id === "clearNotifications") {
            if (notificationApp === "") NotificationService.clearAll();
            else NotificationService.dismissGroup(notificationApp);
            notificationApp = "";
        }
        else if (id === "dnd") NotificationService.toggleDnd();
        else if (id === "clipboardWindow") ClipboardService.windowOpen = true;
        else if (id === "incognito") ClipboardService.incognito = !ClipboardService.incognito;
        else if (id === "clearClipboard") ClipboardService.clearClipboard();
        else if (item.clip !== undefined) ClipboardService.copyEntry(item.clip);
        else if (id === "kdePing") { if (phone) KdeConnectService.ping(phone.id); }
        else if (id === "kdeRing") { if (phone) KdeConnectService.ring(phone.id); }
        else if (id === "kdeClipboard") { if (phone) KdeConnectService.sendClipboard(phone.id); }
        else if (id === "kdeFile") { if (phone) KdeConnectService.pickAndShare(phone.id); }
        else if (id === "rescanDrives") DeviceService.scanDevices();
        else if (item.drive) {
            if (item.mounted) DeviceService.openDevice(item.mountpoint);
            else DeviceService.mountDevice(item.drive);
        }
        else if (id.indexOf("game:") === 0) return true;
        else return false;
        return true;
    }

    // The confirm action waiting for its second click, and how long it waits
    property string armedAction: ""

    Timer {
        id: armTimer
        interval: Logic.CONFIRM_MS
        onTriggered: root.armedAction = ""
    }

    // Whether a toggle action is on
    function actionOn(item) {
        if (item.id === "lowRefresh") return SettingsService.lowRefreshOnBattery;
        if (item.network) return item.inUse || NetworkService.connectingSsid === item.network;
        if (item.device) return item.inUse || BluetoothService.connectingMac === item.device;
        if (item.source) return item.inUse;
        return false;
    }

    function actionEnabled(item) {
        if (item.id === "lowRefresh") return PowerProfileService.lowRefreshAvailable;
        if (item.id === "systemMonitor") return HardwareStatsService.systemMonitorProblem === "";
        // KDE's settings modules, which other desktops may not have
        if (Logic.KDE_SETTINGS_TILES.indexOf(item.id) >= 0) return DepsService.problem(["systemsettings"]) === "";
        return true;
    }

    // Runs a page's action tile. Restart and Shut Down arm on the first click and run on
    // the second. Toggles, networks and Rescan leave the dial open; the rest close it.
    function runAction(item) {
        if (!actionEnabled(item)) return;
        if (item.confirm && armedAction !== item.id) {
            armedAction = item.id;
            armTimer.restart();
            return;
        }
        armedAction = "";
        armTimer.stop();
        if (item.card) {
            cardRequested(item.card);
            return;
        }
        if (item.section) {
            close();
            SettingsService.requestOpenSettings("Top bar", item.section);
            return;
        }
        if (pageAction(item)) {
            if (!item.stay) close();
            return;
        }
        if (item.toggle) {
            if (item.id === "lowRefresh") SettingsService.setSetting("lowRefreshOnBattery", !SettingsService.lowRefreshOnBattery);
            return;
        }
        if (item.network) {
            passwordFor = "";
            if (item.inUse || NetworkService.connectingSsid !== "") return;
            if (Logic.needsPassword(item)) passwordFor = item.network;
            else NetworkService.connectTo(item.network);
            return;
        }
        if (item.device) {
            BluetoothService.toggleConnection(item.device, item.inUse);
            return;
        }
        if (item.source) {
            MicrophoneService.setSource(item.source);
            return;
        }
        if (item.id === "rescan") {
            NetworkService.scanWifi();
            return;
        }
        close();
        switch (item.id) {
        case "wifiSettings": NetworkService.openSettings(); break;
        case "bluetoothSettings": BluetoothService.openSettings(); break;
        case "audioSettings": Quickshell.execDetached(["systemsettings", "kcm_pulseaudio"]); break;
        case "systemMonitor": HardwareStatsService.openSystemMonitor(); break;
        case "settings": PowerService.openSettings(); break;
        case "lock": PowerService.lock(); break;
        case "sleep": PowerService.sleep(); break;
        case "restart": PowerService.restart(); break;
        case "shutdown": PowerService.shutdown(); break;
        }
    }

    onOpenChanged: {
        if (open) {
            SettingsPagesService.load();
        } else {
            query = "";
            scope = 0;
            page = "";
            armedAction = "";
            passwordFor = "";
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
    readonly property var ringLabels: {
        if (page === "power") return profilesAvailable ? Logic.PROFILES.map(p => p.name) : ["Power"];
        if (page === "wifi") return Logic.WIFI_RING;
        if (page === "bluetooth") return Logic.BLUETOOTH_RING;
        if (page === "hardware") return Logic.HARDWARE_RING;
        if (page === "mic") return Logic.MIC_RING;
        if (page === "nightLight") return NightLightService.available ? Pages.NIGHT_RING : ["Night Light"];
        if (page === "hue") return Pages.hueRing(HueService.lights);
        if (page === "notification") return Pages.notificationRing(NotificationService.groups);
        if (page === "clipboard") return Pages.CLIPBOARD_RING;
        if (page === "kdeConnect") return Pages.kdeRing(KdeConnectService.devices);
        if (page === "usb") return ["Drives"];
        if (page === "gameMode") return GameModeService.available ? Pages.GAME_RING : ["GameMode"];
        if (searching) return Logic.scopeLabels(appHits, settingHits, fileHits);
        return Logic.CATEGORIES.map(c => c.name);
    }
    readonly property int ringIndex: {
        if (page === "power") return profilesAvailable ? Logic.profileIndex(PowerProfileService.activeProfile) : 0;
        if (page === "wifi") return NetworkService.isWifiEnabled ? 1 : 0;
        if (page === "bluetooth") return BluetoothService.isEnabled ? 1 : 0;
        if (page === "hardware") return hardwareMetric;
        if (page === "mic") return MicrophoneService.isMuted ? 0 : 1;
        if (page === "nightLight") return NightLightService.available && NightLightService.switchedOn ? 1 : 0;
        if (page === "hue") return Pages.hueIndex(HueService.lights, HueService.selectedLight);
        if (page === "notification") return Pages.notificationIndex(NotificationService.groups, notificationApp);
        if (page === "clipboard") return clipboardFilter;
        if (page === "kdeConnect") return Pages.hueIndex(KdeConnectService.devices, KdeConnectService.device);
        if (page === "usb") return 0;
        if (page === "gameMode") return GameModeService.available && GameModeService.forced ? 1 : 0;
        return searching ? scope : category;
    }
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
    readonly property var items: {
        if (page === "power") return Logic.POWER_ACTIONS;
        if (page === "mic") return Logic.micItems(MicrophoneService.sources);
        if (page === "nightLight") return Pages.nightLightItems(NightLightService.available, NightLightService.shownMode,
            NightLightService.scheduleStart, NightLightService.scheduleEnd);
        if (page === "hue") return Pages.hueItems(HueService.selectedLight, HueService.favouriteId);
        if (page === "notification") return Pages.notificationItems(NotificationService.notifications || [], notificationApp, SettingsService.dndEnabled);
        if (page === "clipboard") return Pages.clipboardItems(clipboardEntries, ClipboardService.incognito, ClipboardService.history.length > 0);
        if (page === "kdeConnect") return Pages.kdeItems(KdeConnectService.device);
        if (page === "usb") return Pages.driveItems(DeviceService.devices, DeviceService.operatingDevice);
        if (page === "gameMode") return Pages.gameItems(GameModeService.games);
        if (page === "hardware") return Logic.hardwareItems(HardwareStatsService.processes, hardwareMetric).map(i => i.process ? withApp(i) : i);
        if (page === "bluetooth") return Logic.bluetoothItems(BluetoothService.pairedDevices, BluetoothService.isEnabled);
        if (page === "wifi") return Logic.wifiItems(NetworkService.availableNetworks, NetworkService.isWifiEnabled, NetworkService.savedSsids);
        if (searching) return Logic.arrange(Logic.scopeHits(scope, query, appHits, settingHits, fileHits));
        return Logic.itemsFor(category, apps, pinnedIds, DockService.usageStats, windowItems);
    }

    // Where app positions are remembered: per category, or per scope and text while searching
    readonly property string focusKey: {
        if (page !== "") return "page:" + page;
        return searching ? "?" + scope + ":" + trimmedQuery : String(category);
    }

    readonly property int focusIndex: {
        let remembered = focusMemory[focusKey];
        if (items.length === 0) return 0;
        let start = page !== "" ? Logic.pageFocus(page, items) : Logic.middle(items.length);
        return Logic.clamp(remembered !== undefined ? remembered : start, 0, items.length - 1);
    }

    function setCategory(index) {
        animateTurn();
        category = Logic.clamp(index, 0, Logic.CATEGORIES.length - 1);
    }

    // The ring's selection: a category, or a scope while searching
    function setRing(index) {
        animateTurn();
        if (page === "power") {
            if (profilesAvailable) PowerProfileService.setProfile(Logic.PROFILES[Logic.clamp(index, 0, Logic.PROFILES.length - 1)].id);
        } else if (page === "wifi") {
            if ((Logic.clamp(index, 0, 1) === 1) !== NetworkService.isWifiEnabled) NetworkService.toggleWifi();
        } else if (page === "hardware") {
            hardwareMetric = Logic.clamp(index, 0, Logic.HARDWARE_RING.length - 1);
        } else if (page === "bluetooth") {
            if ((Logic.clamp(index, 0, 1) === 1) !== BluetoothService.isEnabled) BluetoothService.togglePower();
        } else if (page === "mic") {
            MicrophoneService.setMute(Logic.clamp(index, 0, 1) === 0);
        } else if (page === "nightLight") {
            let on = Logic.clamp(index, 0, 1) === 1;
            if (NightLightService.available && on !== NightLightService.switchedOn) NightLightService.setActive(on);
        } else if (page === "hue") {
            let lights = HueService.lights;
            if (lights.length > 0) HueService.selectLight(lights[Logic.clamp(index, 0, lights.length - 1)].id);
        } else if (page === "notification") {
            let groups = NotificationService.groups;
            let i = Logic.clamp(index, 0, groups.length);
            notificationApp = i === 0 ? "" : groups[i - 1].appName;
            dropPageFocus();
        } else if (page === "clipboard") {
            clipboardFilter = Logic.clamp(index, 0, Pages.CLIPBOARD_RING.length - 1);
            dropPageFocus();
        } else if (page === "kdeConnect") {
            let phones = KdeConnectService.devices;
            if (phones.length > 0) KdeConnectService.selectDevice(phones[Logic.clamp(index, 0, phones.length - 1)].id);
        } else if (page === "gameMode") {
            let force = Logic.clamp(index, 0, 1) === 1;
            if (GameModeService.available && force !== GameModeService.forced) GameModeService.setForced(force);
        } else if (page === "usb") {
            // One pill, nothing to choose
        } else if (searching) scope = Logic.clamp(index, 0, Logic.SCOPES.length - 1);
        else setCategory(index);
    }

    // After a page's ring changes its list, the arc starts over on the list's own slot
    function dropPageFocus() {
        let memory = Object.assign({}, focusMemory);
        delete memory[focusKey];
        focusMemory = memory;
    }

    function setFocus(index) {
        animateTurn();
        armedAction = "";
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
        if (item.kind === "action") {
            runAction(item);
        } else if (item.kind === "window") {
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
        } else if (item.kind === "notification") {
            add("Dismiss", "close", () => NotificationService.dismissNotification(item.notification));
            add("Dismiss All from " + item.app, "trash", () => NotificationService.dismissGroup(item.app));
        } else if (item.clip !== undefined) {
            add("Copy", "copy", () => launch(item, x, y));
            add(item.pinned ? "Unpin" : "Pin", "pin", () => ClipboardService.togglePinned(item.clip));
            add("Remove", "trash", () => ClipboardService.removeEntry(item.clip));
        } else if (item.drive) {
            if (item.mounted) {
                add("Open", "folder", () => launch(item, x, y));
                add("Unmount", "close", () => DeviceService.unmountDevice(item.drive));
            } else {
                add("Mount", "plus", () => DeviceService.mountDevice(item.drive));
            }
            add("Eject", "power", () => DeviceService.powerOffDevice(item.parent));
        } else if (item.kind === "process") {
            if (Logic.canEnd(item.process)) add("End " + item.name, "close", () => HardwareStatsService.endProgram(item.process));
            if (HardwareStatsService.systemMonitorProblem === "") add("Open System Monitor", "cpu", () => HardwareStatsService.openSystemMonitor(), true);
        }
        return entries;
    }

    // Runs the entry from where its tile sits. Terminal apps are wrapped in a terminal
    // (WindowService.launchInTerminal), because DesktopEntry.execute() ignores runInTerminal.
    function start(item, x, y) {
        if (!item) return;
        if (item.kind === "app") {
            let entry = item.entry;
            DockService.recordUse({ "id": item.id });
            if (entry.runInTerminal && entry.command && entry.command.length > 0)
                WindowService.launchInTerminal(entry.command, entry.id, entry.workingDirectory);
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
