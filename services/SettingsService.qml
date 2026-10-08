pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "settingsMigration.js" as SettingsMigration

Singleton {
    id: root

    // Config file path
    readonly property string settingsFilePath: Quickshell.shellDir + "/settings.json"

    // User settings properties (with default values matching Theme.qml)
    property real uiScale: 1.0
    property real fontScale: 1.0
    // Name of an entry in Theme.accentChoices
    property string accentColor: "blue"
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
    property bool showWifiIcon: true
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
    property bool showTimerInPill: true

    // Expanded island widgets: id -> enabled. Ids missing here use the
    // registry default (see WidgetRegistry).
    property var widgets: ({})

    // App Launcher Customization
    property string launcherDefaultView: "grid"
    property string launcherDensity: "comfortable"
    property string launcherStartTab: "All"
    property bool launcherShowCategories: true
    property int launcherGridColumns: 4
    property bool launcherShowGenericNames: true

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

    // Process to read settings.json on startup
    Process {
        id: loadProc
        command: ["python3", "-c", "import sys, os; p=sys.argv[1]; sys.stdout.write(open(p).read() if os.path.exists(p) else '')", root.settingsFilePath]
        running: true

        stdout: StdioCollector {
            onTextChanged: {
                let t = text.trim();
                if (t.length > 0) {
                    try {
                        let data = JSON.parse(t);
                        console.info("[SettingsService] Settings loaded successfully from settings.json");
                        root.applySettings(data);
                    } catch(e) {
                        console.warn("[SettingsService] Error parsing settings.json: " + e);
                    }
                }
            }
        }
    }

    function loadSettings() {
        if (!loadProc.running) {
            loadProc.running = true;
        }
    }

    function applySettings(data) {
        if (!data || typeof data !== "object") return;

        if (data.uiScale !== undefined && !isNaN(data.uiScale)) root.uiScale = Math.max(0.80, Math.min(1.25, parseFloat(data.uiScale)));
        if (data.fontScale !== undefined && !isNaN(data.fontScale)) root.fontScale = Math.max(0.85, Math.min(1.25, parseFloat(data.fontScale)));

        if (data.accentColor !== undefined && Theme.accentChoices.some(c => c.name === data.accentColor)) root.accentColor = data.accentColor;

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
        if (data.showWifiIcon !== undefined) root.showWifiIcon = !!data.showWifiIcon;
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

        if (data.showWindowControls !== undefined) root.showWindowControls = !!data.showWindowControls;
        if (data.autoHideWindowControls !== undefined) root.autoHideWindowControls = !!data.autoHideWindowControls;
        if (data.showVirtualDesktops !== undefined) root.showVirtualDesktops = !!data.showVirtualDesktops;
        if (data.autoHideVirtualDesktops !== undefined) root.autoHideVirtualDesktops = !!data.autoHideVirtualDesktops;

        if (data.showAppTrayPill !== undefined) root.showAppTrayPill = !!data.showAppTrayPill;
        if (data.autoHideAppTrayPill !== undefined) root.autoHideAppTrayPill = !!data.autoHideAppTrayPill;
        if (data.showDetachedNotifBubble !== undefined) root.showDetachedNotifBubble = !!data.showDetachedNotifBubble;
        if (data.showOsd !== undefined) root.showOsd = !!data.showOsd;
        if (data.showTimerInPill !== undefined) root.showTimerInPill = !!data.showTimerInPill;

        // Also reads the per-widget keys used by older configs
        root.widgets = SettingsMigration.widgetStates(data, WidgetRegistry.widgets.map(w => w.id));

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

        // Sync with Theme singleton
        root.syncToTheme();
        root.isLoaded = true;
        root.settingsChanged();
    }

    function syncToTheme() {
        Theme.uiScale = root.uiScale;
        Theme.fontScale = root.fontScale;
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

    function resetDefaults() {
        root.uiScale = 1.0;
        root.fontScale = 1.0;
        root.accentColor = "blue";
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
        root.showWifiIcon = true;
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

        root.showWindowControls = true;
        root.autoHideWindowControls = false;
        root.showVirtualDesktops = true;
        root.autoHideVirtualDesktops = false;

        root.showAppTrayPill = true;
        root.autoHideAppTrayPill = false;
        root.showDetachedNotifBubble = true;
        root.showOsd = true;
        root.showTimerInPill = true;

        root.widgets = {};

        root.launcherDefaultView = "grid";
        root.launcherDensity = "comfortable";
        root.launcherStartTab = "All";
        root.launcherShowCategories = true;
        root.launcherGridColumns = 4;
        root.launcherShowGenericNames = true;

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
            "accentColor": root.accentColor,
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
            "showWifiIcon": root.showWifiIcon,
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
            "showWindowControls": root.showWindowControls,
            "autoHideWindowControls": root.autoHideWindowControls,
            "showVirtualDesktops": root.showVirtualDesktops,
            "autoHideVirtualDesktops": root.autoHideVirtualDesktops,
            "showAppTrayPill": root.showAppTrayPill,
            "autoHideAppTrayPill": root.autoHideAppTrayPill,
            "showDetachedNotifBubble": root.showDetachedNotifBubble,
            "showOsd": root.showOsd,
            "showTimerInPill": root.showTimerInPill,
            "widgets": root.widgetStates(),
            "launcherDefaultView": root.launcherDefaultView,
            "launcherDensity": root.launcherDensity,
            "launcherStartTab": root.launcherStartTab,
            "launcherShowCategories": root.launcherShowCategories,
            "launcherGridColumns": root.launcherGridColumns,
            "launcherShowGenericNames": root.launcherShowGenericNames
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
