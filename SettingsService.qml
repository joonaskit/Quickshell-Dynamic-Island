pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Config file path
    readonly property string settingsFilePath: Quickshell.shellDir + "/settings.json"

    // User settings properties (with default values matching Theme.qml)
    property real uiScale: 1.0
    property real fontScale: 1.0
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
    property real dockScaleHover: 1.28

    // Top Right Status Cluster icon toggles
    property bool showCaffeineIcon: true
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

    // Expanded Island Widget Cards
    property bool showExpandedCalendar: true
    property bool showExpandedMedia: true
    property bool showExpandedNotifications: true
    property bool showExpandedAudioSink: true
    property bool showExpandedVolume: true
    property bool showExpandedBrightness: true

    property bool isLoaded: false
    property string lastSavedTime: ""

    // Signal emitted when any setting changes
    signal settingsChanged()

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
                        console.warn("[SettingsService] Settings loaded successfully from settings.json");
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
        if (data.dockScaleHover !== undefined && !isNaN(data.dockScaleHover)) root.dockScaleHover = parseFloat(data.dockScaleHover);
        if (data.autoCollapseTimeout !== undefined && !isNaN(data.autoCollapseTimeout)) root.autoCollapseTimeout = parseInt(data.autoCollapseTimeout);

        if (data.showCaffeineIcon !== undefined) root.showCaffeineIcon = !!data.showCaffeineIcon;
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

        if (data.showExpandedCalendar !== undefined) root.showExpandedCalendar = !!data.showExpandedCalendar;
        if (data.showExpandedMedia !== undefined) root.showExpandedMedia = !!data.showExpandedMedia;
        if (data.showExpandedNotifications !== undefined) root.showExpandedNotifications = !!data.showExpandedNotifications;
        if (data.showExpandedAudioSink !== undefined) root.showExpandedAudioSink = !!data.showExpandedAudioSink;
        if (data.showExpandedVolume !== undefined) root.showExpandedVolume = !!data.showExpandedVolume;
        if (data.showExpandedBrightness !== undefined) root.showExpandedBrightness = !!data.showExpandedBrightness;

        // Sync with Theme singleton
        root.syncToTheme();
        root.isLoaded = true;
        root.settingsChanged();
    }

    function syncToTheme() {
        Theme.uiScale = root.uiScale;
        Theme.fontScale = root.fontScale;
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

    function resetDefaults() {
        root.uiScale = 1.0;
        root.fontScale = 1.0;
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
        root.dockScaleHover = 1.28;

        root.showCaffeineIcon = true;
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

        root.showExpandedCalendar = true;
        root.showExpandedMedia = true;
        root.showExpandedNotifications = true;
        root.showExpandedAudioSink = true;
        root.showExpandedVolume = true;
        root.showExpandedBrightness = true;

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
            "dockScaleHover": root.dockScaleHover,
            "showCaffeineIcon": root.showCaffeineIcon,
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
            "showExpandedCalendar": root.showExpandedCalendar,
            "showExpandedMedia": root.showExpandedMedia,
            "showExpandedNotifications": root.showExpandedNotifications,
            "showExpandedAudioSink": root.showExpandedAudioSink,
            "showExpandedVolume": root.showExpandedVolume,
            "showExpandedBrightness": root.showExpandedBrightness
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
