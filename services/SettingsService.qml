pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "settingsMigration.js" as SettingsMigration
import "launcherExtras.js" as LauncherExtras

Singleton {
    id: root

    // Config file path
    readonly property string settingsFilePath: Quickshell.shellDir + "/settings.json"

    // User settings properties (with default values matching Theme.qml)
    property real uiScale: 1.0
    property real fontScale: 1.0
    // Font family names; empty means the default fonts, and an empty display font follows the interface font
    property string fontFamily: ""
    property string fontDisplayFamily: ""
    // "dark" or "light"
    property string colorScheme: "dark"
    // Name of an entry in Theme.accentChoices
    property string accentColor: "blue"
    // Name of an entry in Theme.cornerChoices
    property string cornerStyle: "default"
    property bool use24Hour: true
    property bool showSeconds: false
    property bool showBattery: true
    property bool showMediaWhenPlaying: true
    property bool morphToTopBarWhenMaximized: true
    property bool reserveSpaceWhenMaximized: true
    property bool hideOnFullscreen: true
    property int autoCollapseTimeout: 6000

    // Dock behavior
    property bool dockAutoHideOnFullscreen: true
    property bool dockAutoHideFromWindows: true
    property bool dockAutoHideAlways: false
    property bool dockShowDownloads: true
    property bool dockShowTrash: true
    property bool dockShowBorder: false
    property bool dockTransparent: false
    // Name of an entry in Theme.dockTintChoices
    property string dockTint: "cool"
    property real dockTintStrength: 0.08
    // Dock opacity, kept separately for the solid look and the transparent glass look
    property real dockOpacity: 0.85
    property real dockGlassOpacity: 0.35
    property string dockPosition: "bottom"
    property int dockIconSize: 44
    property real dockScaleHover: 1.28

    // Top Right Status Cluster icon toggles
    property bool showCaffeineIcon: true
    property bool showDndIcon: true
    property bool dndEnabled: false
    property bool caffeineEnabled: false
    property bool showWifiIcon: true
    // Hide status icons whose tools are missing, instead of showing them dimmed
    property bool hideUnavailableIcons: false
    property bool showBluetoothIcon: true
    property bool showMicIcon: true
    property bool showClipboardIcon: true
    property bool showProfileIcon: true
    property bool showHardwareIcon: true
    property bool showUsbIcon: true
    property bool pinUsbIcon: false
    property bool showNotificationIcon: true
    property bool pinNotificationIcon: false
    property bool showBatteryIcon: true
    // Saved left-to-right order of the status-bar icons, as ids (see
    // StatusIconRegistry). Empty means registry order, and ids missing from it
    // go at the end.
    property var statusIconOrder: []
    readonly property var orderedStatusIcons: SettingsMigration.savedOrder(root.statusIconOrder, StatusIconRegistry.icons.map(i => i.id)).map(id => StatusIconRegistry.byId(id))

    // Top Left Pills (Window Controls & Virtual Desktops)
    property bool showWindowControls: true
    property bool autoHideWindowControls: false
    property bool showVirtualDesktops: true
    property bool autoHideVirtualDesktops: false

    // App Indicator & Detached Bubble
    property bool showAppTrayPill: true
    property bool autoHideAppTrayPill: false
    property bool showDetachedNotifBubble: true
    property bool showOsd: true
    property bool showDesktopOsd: true
    property bool showTimerInPill: true
    property bool showActivitiesInPill: true

    // Expanded island widgets: id -> enabled. Ids missing here use the
    // registry default (see WidgetRegistry).
    property var widgets: ({})
    // Saved display order of the widgets, as ids. Empty means registry order,
    // and ids missing from it go at the end.
    property var widgetOrder: []
    readonly property var orderedWidgets: SettingsMigration.savedOrder(root.widgetOrder, WidgetRegistry.widgets.map(w => w.id)).map(id => WidgetRegistry.byId(id))

    // App Launcher Customization
    property string launcherDefaultView: "grid"
    property string launcherDensity: "comfortable"
    property string launcherStartTab: "All"
    property bool launcherShowCategories: true
    property int launcherGridColumns: 4
    property bool launcherShowGenericNames: true
    // Instant answers in the launcher's search box
    property bool launcherCalculator: true
    property bool launcherConversion: true
    property bool launcherWebSearch: true
    property var launcherWebShortcuts: LauncherExtras.DEFAULT_SHORTCUTS
    // File search through Filehouse: off until asked for, since it walks the folder on every search
    property bool launcherFileSearch: false
    property string launcherFileSearchKey: "f"
    property string launcherFileSearchRoot: "~"

    // Clipboard history (kept in memory only)
    property int clipboardMaxItems: 50
    // Seconds before an item that looks like a credential is dropped from the history; 0 keeps it
    property int clipboardSensitiveExpiry: 60
    // App ids (lowercase) whose copies are never recorded
    property var clipboardIgnoredApps: []

    // The onboarding version the user has finished or closed; 0 means the welcome guide has
    // not been shown. A settings.json from before onboarding existed counts as done
    readonly property int onboardingCurrent: 1
    property int onboardingVersion: 0

    // GameMode widget. Off by default
    property bool gameModeEnabled: false

    // KDE Connect (phone) widget. Off by default; the id is the device last picked
    property bool kdeConnectEnabled: false
    property string kdeConnectDeviceId: ""

    // Philips Hue lamp control. Off by default; the key is the app key from pairing with the bridge
    property bool hueEnabled: false
    property string hueBridgeIp: ""
    property string hueAppKey: ""
    property string hueLightId: ""

    // KDE Night Light control. Off by default
    property bool nightLightEnabled: false
    // Custom hours: when set, the shell switches Night Light on between the two times ("HH:MM")
    property bool nightLightCustom: false
    property bool nightLightScheduleEnabled: false
    property string nightLightStart: "21:00"
    property string nightLightEnd: "07:00"

    property bool isLoaded: false
    property string lastSavedTime: ""

    // Signal emitted when any setting changes
    signal settingsChanged()

    // Asks the island to open the settings view on a tab (a name from
    // SettingsView.tabs, e.g. "Launcher"). Lets other windows, such as the dock,
    // link to a settings page.
    signal openSettingsRequested(string tab)

    function requestOpenSettings(tab) {
        root.openSettingsRequested(tab || "");
    }

    // Set by reloadFromDisk: the next load starts from the defaults, so keys the file lacks do not keep their old values
    property bool resetOnLoad: false

    // Process to read settings.json on startup, and again after an import
    Process {
        id: loadProc
        command: ["python3", "-c", "import sys, os; p=sys.argv[1]; sys.stdout.write(open(p).read() if os.path.exists(p) else '')", root.settingsFilePath]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let t = text.trim();
                let reset = root.resetOnLoad;
                root.resetOnLoad = false;
                if (t.length > 0) {
                    try {
                        let data = JSON.parse(t);
                        console.info("[SettingsService] Settings loaded successfully from settings.json");
                        if (reset) root.resetDefaults();
                        root.applySettings(data);
                    } catch(e) {
                        console.warn("[SettingsService] Error parsing settings.json: " + e);
                    }
                } else {
                    // No settings.json yet: a new install, running on the defaults
                    root.applySettings({ "onboardingVersion": 0 });
                }
            }
        }
    }

    function loadSettings() {
        if (!loadProc.running) {
            loadProc.running = true;
        }
    }

    // Takes settings.json as it is on disk now (after an import), dropping any unsaved change
    function reloadFromDisk() {
        saveTimer.stop();
        root.resetOnLoad = true;
        loadProc.running = true;
    }

    function applySettings(data) {
        if (!data || typeof data !== "object") return;

        if (data.uiScale !== undefined && !isNaN(data.uiScale)) root.uiScale = Math.max(0.80, Math.min(1.25, parseFloat(data.uiScale)));
        if (data.fontScale !== undefined && !isNaN(data.fontScale)) root.fontScale = Math.max(0.85, Math.min(1.25, parseFloat(data.fontScale)));

        if (typeof data.fontFamily === "string") root.fontFamily = data.fontFamily.trim().slice(0, 100);
        if (typeof data.fontDisplayFamily === "string") root.fontDisplayFamily = data.fontDisplayFamily.trim().slice(0, 100);

        if (data.colorScheme === "dark" || data.colorScheme === "light") root.colorScheme = data.colorScheme;
        if (data.accentColor !== undefined && Theme.accentChoices.some(c => c.name === data.accentColor)) root.accentColor = data.accentColor;

        if (data.cornerStyle !== undefined && Theme.cornerChoices.some(c => c.name === data.cornerStyle)) root.cornerStyle = data.cornerStyle;

        if (data.use24Hour !== undefined) root.use24Hour = !!data.use24Hour;
        if (data.showSeconds !== undefined) root.showSeconds = !!data.showSeconds;
        if (data.showBattery !== undefined) root.showBattery = !!data.showBattery;
        if (data.showMediaWhenPlaying !== undefined) root.showMediaWhenPlaying = !!data.showMediaWhenPlaying;
        if (data.morphToTopBarWhenMaximized !== undefined) root.morphToTopBarWhenMaximized = !!data.morphToTopBarWhenMaximized;
        if (data.reserveSpaceWhenMaximized !== undefined) root.reserveSpaceWhenMaximized = !!data.reserveSpaceWhenMaximized;
        if (data.hideOnFullscreen !== undefined) root.hideOnFullscreen = !!data.hideOnFullscreen;
        if (data.dockAutoHideOnFullscreen !== undefined) root.dockAutoHideOnFullscreen = !!data.dockAutoHideOnFullscreen;
        if (data.dockAutoHideFromWindows !== undefined) root.dockAutoHideFromWindows = !!data.dockAutoHideFromWindows;
        if (data.dockAutoHideAlways !== undefined) root.dockAutoHideAlways = !!data.dockAutoHideAlways;
        if (data.dockShowDownloads !== undefined) root.dockShowDownloads = !!data.dockShowDownloads;
        if (data.dockShowTrash !== undefined) root.dockShowTrash = !!data.dockShowTrash;
        if (data.dockShowBorder !== undefined) root.dockShowBorder = !!data.dockShowBorder;
        if (data.dockTransparent !== undefined) root.dockTransparent = !!data.dockTransparent;
        if (data.dockTint !== undefined && Theme.dockTintChoices.some(c => c.name === data.dockTint)) root.dockTint = data.dockTint;
        if (data.dockTintStrength !== undefined && !isNaN(data.dockTintStrength)) root.dockTintStrength = Math.max(0.02, Math.min(0.20, parseFloat(data.dockTintStrength)));
        if (data.dockOpacity !== undefined && !isNaN(data.dockOpacity)) root.dockOpacity = Math.max(0.20, Math.min(1.0, parseFloat(data.dockOpacity)));
        if (data.dockGlassOpacity !== undefined && !isNaN(data.dockGlassOpacity)) root.dockGlassOpacity = Math.max(0.20, Math.min(1.0, parseFloat(data.dockGlassOpacity)));
        if (data.dockPosition !== undefined && (data.dockPosition === "bottom" || data.dockPosition === "left" || data.dockPosition === "right")) {
            root.dockPosition = data.dockPosition;
        }
        if (data.dockIconSize !== undefined && !isNaN(data.dockIconSize)) {
            root.dockIconSize = Math.max(36, Math.min(64, parseInt(data.dockIconSize)));
        }
        if (data.dockScaleHover !== undefined && !isNaN(data.dockScaleHover)) {
            root.dockScaleHover = Math.max(1.0, Math.min(1.5, parseFloat(data.dockScaleHover)));
        }
        if (data.autoCollapseTimeout !== undefined && !isNaN(data.autoCollapseTimeout)) root.autoCollapseTimeout = parseInt(data.autoCollapseTimeout);

        if (data.showCaffeineIcon !== undefined) root.showCaffeineIcon = !!data.showCaffeineIcon;
        if (data.showDndIcon !== undefined) root.showDndIcon = !!data.showDndIcon;
        if (data.dndEnabled !== undefined) root.dndEnabled = !!data.dndEnabled;
        if (data.caffeineEnabled !== undefined) root.caffeineEnabled = !!data.caffeineEnabled;
        if (data.showWifiIcon !== undefined) root.showWifiIcon = !!data.showWifiIcon;
        if (data.hideUnavailableIcons !== undefined) root.hideUnavailableIcons = !!data.hideUnavailableIcons;
        if (data.showBluetoothIcon !== undefined) root.showBluetoothIcon = !!data.showBluetoothIcon;
        if (data.showMicIcon !== undefined) root.showMicIcon = !!data.showMicIcon;
        if (data.showClipboardIcon !== undefined) root.showClipboardIcon = !!data.showClipboardIcon;
        if (data.showProfileIcon !== undefined) root.showProfileIcon = !!data.showProfileIcon;
        if (data.showHardwareIcon !== undefined) root.showHardwareIcon = !!data.showHardwareIcon;
        if (data.showUsbIcon !== undefined) root.showUsbIcon = !!data.showUsbIcon;
        if (data.pinUsbIcon !== undefined) root.pinUsbIcon = !!data.pinUsbIcon;
        if (data.showNotificationIcon !== undefined) root.showNotificationIcon = !!data.showNotificationIcon;
        if (data.pinNotificationIcon !== undefined) root.pinNotificationIcon = !!data.pinNotificationIcon;
        if (data.showBatteryIcon !== undefined) root.showBatteryIcon = !!data.showBatteryIcon;
        let savedIconOrder = Array.isArray(data.statusIconOrder) ? SettingsMigration.savedOrder(data.statusIconOrder, StatusIconRegistry.icons.map(i => i.id)) : [];
        if (JSON.stringify(savedIconOrder) !== JSON.stringify(root.statusIconOrder)) root.statusIconOrder = savedIconOrder;
        if (data.nightLightEnabled !== undefined) root.nightLightEnabled = !!data.nightLightEnabled;
        if (data.nightLightCustom !== undefined) root.nightLightCustom = !!data.nightLightCustom;
        if (data.nightLightScheduleEnabled !== undefined) root.nightLightScheduleEnabled = !!data.nightLightScheduleEnabled;
        if (typeof data.nightLightStart === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(data.nightLightStart)) root.nightLightStart = data.nightLightStart;
        if (typeof data.nightLightEnd === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(data.nightLightEnd)) root.nightLightEnd = data.nightLightEnd;
        root.onboardingVersion = (data.onboardingVersion !== undefined && !isNaN(data.onboardingVersion))
            ? Math.max(0, parseInt(data.onboardingVersion)) : root.onboardingCurrent;
        if (data.gameModeEnabled !== undefined) root.gameModeEnabled = !!data.gameModeEnabled;
        if (data.kdeConnectEnabled !== undefined) root.kdeConnectEnabled = !!data.kdeConnectEnabled;
        if (typeof data.kdeConnectDeviceId === "string" && /^[A-Za-z0-9_]{0,100}$/.test(data.kdeConnectDeviceId)) root.kdeConnectDeviceId = data.kdeConnectDeviceId;
        if (data.hueEnabled !== undefined) root.hueEnabled = !!data.hueEnabled;
        if (typeof data.hueBridgeIp === "string") root.hueBridgeIp = data.hueBridgeIp.trim().slice(0, 100);
        if (typeof data.hueAppKey === "string") root.hueAppKey = data.hueAppKey.trim().slice(0, 200);
        if (typeof data.hueLightId === "string") root.hueLightId = data.hueLightId.trim().slice(0, 100);

        if (data.showWindowControls !== undefined) root.showWindowControls = !!data.showWindowControls;
        if (data.autoHideWindowControls !== undefined) root.autoHideWindowControls = !!data.autoHideWindowControls;
        if (data.showVirtualDesktops !== undefined) root.showVirtualDesktops = !!data.showVirtualDesktops;
        if (data.autoHideVirtualDesktops !== undefined) root.autoHideVirtualDesktops = !!data.autoHideVirtualDesktops;

        if (data.showAppTrayPill !== undefined) root.showAppTrayPill = !!data.showAppTrayPill;
        if (data.autoHideAppTrayPill !== undefined) root.autoHideAppTrayPill = !!data.autoHideAppTrayPill;
        if (data.showDetachedNotifBubble !== undefined) root.showDetachedNotifBubble = !!data.showDetachedNotifBubble;
        if (data.showOsd !== undefined) root.showOsd = !!data.showOsd;
        if (data.showDesktopOsd !== undefined) root.showDesktopOsd = !!data.showDesktopOsd;
        if (data.showTimerInPill !== undefined) root.showTimerInPill = !!data.showTimerInPill;
        if (data.showActivitiesInPill !== undefined) root.showActivitiesInPill = !!data.showActivitiesInPill;

        // Also reads the per-widget keys used by older configs
        root.widgets = SettingsMigration.widgetStates(data, WidgetRegistry.widgets.map(w => w.id));
        // Only assigned when it differs, as a new order rebuilds the expanded view
        let savedOrder = Array.isArray(data.widgetOrder) ? SettingsMigration.savedOrder(data.widgetOrder, WidgetRegistry.widgets.map(w => w.id)) : [];
        if (JSON.stringify(savedOrder) !== JSON.stringify(root.widgetOrder)) root.widgetOrder = savedOrder;

        if (data.launcherDefaultView !== undefined && (data.launcherDefaultView === "grid" || data.launcherDefaultView === "list")) {
            root.launcherDefaultView = data.launcherDefaultView;
        }
        if (data.launcherStartTab !== undefined && (data.launcherStartTab === "All" || data.launcherStartTab === "Recent" || data.launcherStartTab === "Frequent")) {
            root.launcherStartTab = data.launcherStartTab;
        }
        if (data.launcherDensity !== undefined && (data.launcherDensity === "comfortable" || data.launcherDensity === "compact")) {
            root.launcherDensity = data.launcherDensity;
        }
        if (data.launcherShowCategories !== undefined) root.launcherShowCategories = !!data.launcherShowCategories;
        if (data.launcherGridColumns !== undefined && !isNaN(data.launcherGridColumns)) {
            root.launcherGridColumns = Math.max(3, Math.min(6, parseInt(data.launcherGridColumns)));
        }
        if (data.launcherShowGenericNames !== undefined) root.launcherShowGenericNames = !!data.launcherShowGenericNames;
        if (data.launcherCalculator !== undefined) root.launcherCalculator = !!data.launcherCalculator;
        if (data.launcherConversion !== undefined) root.launcherConversion = !!data.launcherConversion;
        if (data.launcherWebSearch !== undefined) root.launcherWebSearch = !!data.launcherWebSearch;
        if (data.launcherFileSearch !== undefined) root.launcherFileSearch = !!data.launcherFileSearch;
        if (typeof data.launcherFileSearchKey === "string" && /^\S{1,12}$/.test(data.launcherFileSearchKey)) root.launcherFileSearchKey = data.launcherFileSearchKey;
        if (typeof data.launcherFileSearchRoot === "string" && data.launcherFileSearchRoot.trim() !== "") root.launcherFileSearchRoot = data.launcherFileSearchRoot.trim();
        if (Array.isArray(data.launcherWebShortcuts)) {
            // Round trip through the text form to drop entries without a key or an http(s) URL
            root.launcherWebShortcuts = LauncherExtras.parseShortcuts(LauncherExtras.formatShortcuts(data.launcherWebShortcuts.filter(s => s && typeof s.key === "string" && typeof s.url === "string").map(s => ({ key: s.key, name: String(s.name || s.key), url: s.url }))));
        }
        if (data.clipboardMaxItems !== undefined && !isNaN(data.clipboardMaxItems)) {
            root.clipboardMaxItems = Math.max(5, Math.min(500, parseInt(data.clipboardMaxItems)));
        }
        if (data.clipboardSensitiveExpiry !== undefined && !isNaN(data.clipboardSensitiveExpiry)) {
            root.clipboardSensitiveExpiry = Math.max(0, Math.min(3600, parseInt(data.clipboardSensitiveExpiry)));
        }
        if (Array.isArray(data.clipboardIgnoredApps)) {
            root.clipboardIgnoredApps = data.clipboardIgnoredApps.map(a => String(a).toLowerCase());
        }

        // Sync with Theme singleton
        root.syncToTheme();
        root.isLoaded = true;
        root.settingsChanged();
    }

    function syncToTheme() {
        Theme.uiScale = root.uiScale;
        Theme.fontScale = root.fontScale;
        Theme.fontFamilyChoice = root.fontFamily;
        Theme.fontDisplayChoice = root.fontDisplayFamily;
        Theme.scheme = root.colorScheme;
        Theme.cornerStyle = root.cornerStyle;
        Theme.accentName = root.accentColor;
        Theme.use24Hour = root.use24Hour;
        Theme.showSeconds = root.showSeconds;
        Theme.showBattery = root.showBattery && root.showBatteryIcon;
        Theme.showMediaWhenPlaying = root.showMediaWhenPlaying;
        Theme.morphToTopBarWhenMaximized = root.morphToTopBarWhenMaximized;
        Theme.reserveSpaceWhenMaximized = root.reserveSpaceWhenMaximized;
        Theme.hideOnFullscreen = root.hideOnFullscreen;
        Theme.dockAutoHideOnFullscreen = root.dockAutoHideOnFullscreen;
        Theme.dockAutoHideFromWindows = root.dockAutoHideFromWindows;
        Theme.dockAutoHideAlways = root.dockAutoHideAlways;
        Theme.dockShowBorder = root.dockShowBorder;
        Theme.dockTransparent = root.dockTransparent;
        Theme.dockTintName = root.dockTint;
        Theme.dockTintStrength = root.dockTintStrength;
        Theme.dockOpacity = root.dockOpacity;
        Theme.dockGlassOpacity = root.dockGlassOpacity;
        Theme.dockPosition = root.dockPosition;
        Theme.baseDockIconSize = root.dockIconSize;
        Theme.dockScaleHover = root.dockScaleHover;
        Theme.autoCollapseTimeout = root.autoCollapseTimeout;
    }

    // Set a setting and automatically debounce save
    function setSetting(key, val) {
        if (root[key] === val) return;
        root[key] = val;
        root.syncToTheme();
        root.settingsChanged();
        saveTimer.restart();
    }

    function toggleSetting(key) {
        root.setSetting(key, !root[key]);
    }

    function isWidgetEnabled(id) {
        if (root.widgets[id] !== undefined) return root.widgets[id];
        let widget = WidgetRegistry.byId(id);
        return widget ? widget.defaultEnabled : false;
    }

    function setWidgetEnabled(id, val) {
        if (root.isWidgetEnabled(id) === val) return;
        let states = Object.assign({}, root.widgets);
        states[id] = val;
        root.widgets = states;
        root.settingsChanged();
        saveTimer.restart();
    }

    // Enabled state of every registered widget, defaults filled in
    function widgetStates() {
        let states = {};
        for (let i = 0; i < WidgetRegistry.widgets.length; i++) {
            let id = WidgetRegistry.widgets[i].id;
            states[id] = root.isWidgetEnabled(id);
        }
        return states;
    }

    // { id: group } for the entries of a registry list
    function groupsOf(entries) {
        let groups = {};
        for (let i = 0; i < entries.length; i++) groups[entries[i].id] = entries[i].group;
        return groups;
    }

    // Whether a widget can move up (delta -1) or down (delta 1) within its group
    function canMoveWidget(id, delta) {
        return SettingsMigration.moveTarget(root.orderedWidgets.map(w => w.id), id, delta, root.groupsOf(WidgetRegistry.widgets)) >= 0;
    }

    function moveWidget(id, delta) {
        if (!root.canMoveWidget(id, delta)) return;
        root.widgetOrder = SettingsMigration.movedOrder(root.orderedWidgets.map(w => w.id), id, delta, root.groupsOf(WidgetRegistry.widgets));
        root.settingsChanged();
        saveTimer.restart();
    }

    // The same for a status-bar icon; up is towards the left
    function canMoveStatusIcon(id, delta) {
        return SettingsMigration.moveTarget(root.orderedStatusIcons.map(i => i.id), id, delta, root.groupsOf(StatusIconRegistry.icons)) >= 0;
    }

    function moveStatusIcon(id, delta) {
        if (!root.canMoveStatusIcon(id, delta)) return;
        root.statusIconOrder = SettingsMigration.movedOrder(root.orderedStatusIcons.map(i => i.id), id, delta, root.groupsOf(StatusIconRegistry.icons));
        root.settingsChanged();
        saveTimer.restart();
    }

    function resetDefaults() {
        root.uiScale = 1.0;
        root.fontScale = 1.0;
        root.fontFamily = "";
        root.fontDisplayFamily = "";
        root.colorScheme = "dark";
        root.accentColor = "blue";
        root.cornerStyle = "default";
        root.use24Hour = true;
        root.showSeconds = false;
        root.showBattery = true;
        root.showMediaWhenPlaying = true;
        root.morphToTopBarWhenMaximized = true;
        root.reserveSpaceWhenMaximized = true;
        root.hideOnFullscreen = true;
        root.autoCollapseTimeout = 6000;
        root.dockAutoHideOnFullscreen = true;
        root.dockAutoHideFromWindows = true;
        root.dockAutoHideAlways = false;
        root.dockShowDownloads = true;
        root.dockShowTrash = true;
        root.dockShowBorder = false;
        root.dockTransparent = false;
        root.dockTint = "cool";
        root.dockTintStrength = 0.08;
        root.dockOpacity = 0.85;
        root.dockGlassOpacity = 0.35;
        root.dockPosition = "bottom";
        root.dockIconSize = 44;
        root.dockScaleHover = 1.28;

        root.showCaffeineIcon = true;
        root.showDndIcon = true;
        root.dndEnabled = false;
        root.caffeineEnabled = false;
        root.showWifiIcon = true;
        root.hideUnavailableIcons = false;
        root.showBluetoothIcon = true;
        root.showMicIcon = true;
        root.showClipboardIcon = true;
        root.showProfileIcon = true;
        root.showHardwareIcon = true;
        root.showUsbIcon = true;
        root.pinUsbIcon = false;
        root.showNotificationIcon = true;
        root.pinNotificationIcon = false;
        root.showBatteryIcon = true;
        root.statusIconOrder = [];
        root.nightLightEnabled = false;
        root.nightLightCustom = false;
        root.nightLightScheduleEnabled = false;
        root.nightLightStart = "21:00";
        root.nightLightEnd = "07:00";
        root.gameModeEnabled = false;
        root.kdeConnectEnabled = false;
        root.kdeConnectDeviceId = "";
        root.hueEnabled = false;
        root.hueBridgeIp = "";
        root.hueAppKey = "";
        root.hueLightId = "";

        root.showWindowControls = true;
        root.autoHideWindowControls = false;
        root.showVirtualDesktops = true;
        root.autoHideVirtualDesktops = false;

        root.showAppTrayPill = true;
        root.autoHideAppTrayPill = false;
        root.showDetachedNotifBubble = true;
        root.showOsd = true;
        root.showDesktopOsd = true;
        root.showTimerInPill = true;
        root.showActivitiesInPill = true;

        root.widgets = {};
        root.widgetOrder = [];

        root.launcherDefaultView = "grid";
        root.launcherDensity = "comfortable";
        root.launcherStartTab = "All";
        root.launcherShowCategories = true;
        root.launcherGridColumns = 4;
        root.launcherShowGenericNames = true;
        root.launcherCalculator = true;
        root.launcherConversion = true;
        root.launcherWebSearch = true;
        root.launcherWebShortcuts = LauncherExtras.DEFAULT_SHORTCUTS;
        root.launcherFileSearch = false;
        root.launcherFileSearchKey = "f";
        root.launcherFileSearchRoot = "~";
        root.clipboardMaxItems = 50;
        root.clipboardSensitiveExpiry = 60;
        root.clipboardIgnoredApps = [];

        root.syncToTheme();
        root.settingsChanged();
        saveTimer.restart();
    }

    // Debounced saver to prevent rapid disk writes while dragging sliders or toggling switches
    Timer {
        id: saveTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.saveSettings();
        }
    }

    // Process to write settings.json
    Process {
        id: saveProc
        command: []
    }

    function saveSettings() {
        let data = {
            "uiScale": root.uiScale,
            "fontScale": root.fontScale,
            "fontFamily": root.fontFamily,
            "fontDisplayFamily": root.fontDisplayFamily,
            "colorScheme": root.colorScheme,
            "accentColor": root.accentColor,
            "cornerStyle": root.cornerStyle,
            "use24Hour": root.use24Hour,
            "showSeconds": root.showSeconds,
            "showBattery": root.showBattery,
            "showMediaWhenPlaying": root.showMediaWhenPlaying,
            "morphToTopBarWhenMaximized": root.morphToTopBarWhenMaximized,
            "reserveSpaceWhenMaximized": root.reserveSpaceWhenMaximized,
            "hideOnFullscreen": root.hideOnFullscreen,
            "autoCollapseTimeout": root.autoCollapseTimeout,
            "dockAutoHideOnFullscreen": root.dockAutoHideOnFullscreen,
            "dockAutoHideFromWindows": root.dockAutoHideFromWindows,
            "dockAutoHideAlways": root.dockAutoHideAlways,
            "dockShowDownloads": root.dockShowDownloads,
            "dockShowTrash": root.dockShowTrash,
            "dockShowBorder": root.dockShowBorder,
            "dockTransparent": root.dockTransparent,
            "dockTint": root.dockTint,
            "dockTintStrength": root.dockTintStrength,
            "dockOpacity": root.dockOpacity,
            "dockGlassOpacity": root.dockGlassOpacity,
            "dockPosition": root.dockPosition,
            "dockIconSize": root.dockIconSize,
            "dockScaleHover": root.dockScaleHover,
            "showCaffeineIcon": root.showCaffeineIcon,
            "showDndIcon": root.showDndIcon,
            "dndEnabled": root.dndEnabled,
            "caffeineEnabled": root.caffeineEnabled,
            "showWifiIcon": root.showWifiIcon,
            "hideUnavailableIcons": root.hideUnavailableIcons,
            "showBluetoothIcon": root.showBluetoothIcon,
            "showMicIcon": root.showMicIcon,
            "showClipboardIcon": root.showClipboardIcon,
            "showProfileIcon": root.showProfileIcon,
            "showHardwareIcon": root.showHardwareIcon,
            "showUsbIcon": root.showUsbIcon,
            "pinUsbIcon": root.pinUsbIcon,
            "showNotificationIcon": root.showNotificationIcon,
            "pinNotificationIcon": root.pinNotificationIcon,
            "showBatteryIcon": root.showBatteryIcon,
            "statusIconOrder": root.statusIconOrder,
            "nightLightEnabled": root.nightLightEnabled,
            "nightLightCustom": root.nightLightCustom,
            "nightLightScheduleEnabled": root.nightLightScheduleEnabled,
            "nightLightStart": root.nightLightStart,
            "nightLightEnd": root.nightLightEnd,
            "onboardingVersion": root.onboardingVersion,
            "gameModeEnabled": root.gameModeEnabled,
            "kdeConnectEnabled": root.kdeConnectEnabled,
            "kdeConnectDeviceId": root.kdeConnectDeviceId,
            "hueEnabled": root.hueEnabled,
            "hueBridgeIp": root.hueBridgeIp,
            "hueAppKey": root.hueAppKey,
            "hueLightId": root.hueLightId,
            "showWindowControls": root.showWindowControls,
            "autoHideWindowControls": root.autoHideWindowControls,
            "showVirtualDesktops": root.showVirtualDesktops,
            "autoHideVirtualDesktops": root.autoHideVirtualDesktops,
            "showAppTrayPill": root.showAppTrayPill,
            "autoHideAppTrayPill": root.autoHideAppTrayPill,
            "showDetachedNotifBubble": root.showDetachedNotifBubble,
            "showOsd": root.showOsd,
            "showDesktopOsd": root.showDesktopOsd,
            "showTimerInPill": root.showTimerInPill,
            "showActivitiesInPill": root.showActivitiesInPill,
            "widgets": root.widgetStates(),
            "widgetOrder": root.widgetOrder,
            "launcherDefaultView": root.launcherDefaultView,
            "launcherDensity": root.launcherDensity,
            "launcherStartTab": root.launcherStartTab,
            "launcherShowCategories": root.launcherShowCategories,
            "launcherGridColumns": root.launcherGridColumns,
            "launcherShowGenericNames": root.launcherShowGenericNames,
            "launcherCalculator": root.launcherCalculator,
            "launcherConversion": root.launcherConversion,
            "launcherWebSearch": root.launcherWebSearch,
            "launcherWebShortcuts": root.launcherWebShortcuts,
            "launcherFileSearch": root.launcherFileSearch,
            "launcherFileSearchKey": root.launcherFileSearchKey,
            "launcherFileSearchRoot": root.launcherFileSearchRoot,
            "clipboardMaxItems": root.clipboardMaxItems,
            "clipboardSensitiveExpiry": root.clipboardSensitiveExpiry,
            "clipboardIgnoredApps": root.clipboardIgnoredApps
        };
        let jsonStr = JSON.stringify(data, null, 2);
        saveProc.command = ["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", root.settingsFilePath, jsonStr];
        saveProc.running = true;
        root.lastSavedTime = Qt.formatTime(new Date(), "hh:mm:ss");
    }

    Component.onCompleted: {
        root.loadSettings();
    }
}
