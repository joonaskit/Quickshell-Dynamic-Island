pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isMaximized: false
    property bool isFocusedWindowMaximized: false
    property bool hasFullscreenApp: false
    property string activeAppTitle: ""
    property string activeAppId: ""
    property string activeWindowTitle: ""
    property string activeWindowId: ""
    property string activeScreen: ""
    property var windowList: []
    property var virtualDesktops: []

    readonly property int desktopCount: virtualDesktops.length
    readonly property int currentDesktopIndex: {
        for (let i = 0; i < virtualDesktops.length; i++) {
            if (virtualDesktops[i].isCurrent) return i;
        }
        return 0;
    }
    readonly property string currentDesktopId: {
        for (let i = 0; i < virtualDesktops.length; i++) {
            if (virtualDesktops[i].isCurrent) return virtualDesktops[i].id;
        }
        return "";
    }
    readonly property string currentDesktopName: {
        for (let i = 0; i < virtualDesktops.length; i++) {
            if (virtualDesktops[i].isCurrent) return virtualDesktops[i].name;
        }
        return "Desktop 1";
    }

    function switchToDesktop(desktopIdOrIndex) {
        if (desktopIdOrIndex === undefined || desktopIdOrIndex === null) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.switchDesktop", String(desktopIdOrIndex)]);
    }

    function nextDesktop() {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.nextDesktop"]);
    }

    function previousDesktop() {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.previousDesktop"]);
    }

    function createDesktop(name) {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.createDesktop", String(name || "")]);
    }

    function removeDesktop(desktopId) {
        if (!desktopId) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.removeDesktop", String(desktopId)]);
    }

    function getDesktopWindowCount(desktopId, desktopIndex) {
        if (!root.windowList || root.windowList.length === 0) return 0;
        let count = 0;
        let dIdxStr = String(desktopIndex);
        for (let i = 0; i < root.windowList.length; i++) {
            let w = root.windowList[i];
            if (!w) continue;
            if (w.desktops && w.desktops.length > 0) {
                if (w.desktops.indexOf(desktopId) >= 0 || w.desktops.indexOf(dIdxStr) >= 0) {
                    count++;
                }
            }
        }
        return count;
    }

    function activateWindow(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.activateWindow", String(idOrApp)]);
    }

    function closeWindow(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.closeWindow", String(idOrApp)]);
    }

    function minimizeWindow(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.minimizeWindow", String(idOrApp)]);
    }

    function maximizeWindow(idOrApp) {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.maximizeWindow", String(idOrApp || "")]);
    }

    function unmaximizeWindow(idOrApp) {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.unmaximizeWindow", String(idOrApp || "")]);
    }

    function toggleMaximize(idOrApp) {
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.toggleMaximizeWindow", String(idOrApp || "")]);
    }

    function toggleKeepAbove(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.toggleKeepAbove", String(idOrApp)]);
    }

    function moveToNextDesktop(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.moveToNextDesktop", String(idOrApp)]);
    }

    function quitApplication(idOrApp) {
        if (!idOrApp) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.quitApplication", String(idOrApp)]);
    }

    function launchNewWindow(appId) {
        if (!appId) return;
        let cleanId = appId.replace(/\.desktop$/, "");
        let entry = DesktopEntries.byId(cleanId);
        if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
        if (entry) {
            entry.execute();
            return;
        }
        Quickshell.execDetached(["gtk-launch", appId.endsWith(".desktop") ? appId : (appId + ".desktop")]);
    }

    function openTerminal() {
        Quickshell.execDetached(["sh", "-c", "konsole || x-terminal-emulator || alacritty || kitty || gnome-terminal"]);
    }

    function openFileManager() {
        Quickshell.execDetached(["dolphin"]);
    }

    function openSettings() {
        Quickshell.execDetached(["systemsettings"]);
    }

    function lockScreen() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    function resolveAppIcon(appId) {
        if (!appId || appId.length === 0) return "";
        let cleanId = appId.replace(/\.desktop$/, "");
        let entry = DesktopEntries.byId(cleanId);
        if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
        let iconName = entry ? entry.icon : appId;
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
            return "file://" + p;
        }
        return "image://icon/" + iconName;
    }

    function getAppWindows(appId) {
        if (!appId || !root.windowList) return [];
        let target = appId.toLowerCase().replace(/\.desktop$/, "");
        let list = [];
        for (let i = 0; i < root.windowList.length; i++) {
            let w = root.windowList[i];
            if (!w || !w.app) continue;
            let a = w.app.toLowerCase().replace(/\.desktop$/, "");
            if (a === target || a.indexOf(target) >= 0 || target.indexOf(a) >= 0) {
                list.push(w);
            }
        }
        return list;
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            trackerProc.running = true;
        }
    }

    Process {
        id: trackerProc
        command: ["python3", Quickshell.shellDir + "/scripts/kwin_window_tracker.py"]
        running: true

        onRunningChanged: {
            if (!running) {
                restartTimer.start();
            }
        }

        stdout: SplitParser {
            onRead: function(line) {
                let t = line.trim();
                if (t === "LAUNCHER_TOGGLE") {
                    DockService.toggleAppLauncherRequested();
                    return;
                }
                if (t.length === 0) return;

                if (t.startsWith("{")) {
                    try {
                        let data = JSON.parse(t);
                        root.isMaximized = !!data.is_max;
                        root.hasFullscreenApp = !!data.is_full;
                        let rawApp = data.app || "";
                        let rawTitle = data.title || "";
                        root.activeScreen = data.screen || "";

                        root.activeAppId = rawApp;
                        root.activeWindowTitle = rawTitle;

                        root.windowList = Array.isArray(data.wins) ? data.wins : [];
                        root.virtualDesktops = Array.isArray(data.desktops) ? data.desktops : [];

                        if (root.windowList && root.windowList.length > 0) {
                            let activeWin = root.windowList.find(function(w) { return w.active; });
                            root.activeWindowId = activeWin ? activeWin.id : "";
                            root.isFocusedWindowMaximized = activeWin ? (activeWin.maximized !== undefined ? !!activeWin.maximized : root.isMaximized) : false;
                        } else {
                            root.activeWindowId = "";
                            root.isFocusedWindowMaximized = (rawApp !== "" && rawApp !== "Desktop") ? root.isMaximized : false;
                        }

                        // Clean formatted app name
                        let appName = "";
                        if (rawApp.length > 0) {
                            let segments = rawApp.split(".");
                            let last = segments[segments.length - 1];
                            if (last.toLowerCase() === "desktop" && segments.length > 1) {
                                last = segments[segments.length - 2];
                            }
                            if (last.length > 0) {
                                appName = last.charAt(0).toUpperCase() + last.slice(1);
                            }
                        }
                        if (appName === "" && rawTitle.length > 0) {
                            let dash = rawTitle.split(" — ");
                            if (dash.length > 1) {
                                appName = dash[dash.length - 1];
                            } else {
                                dash = rawTitle.split(" - ");
                                if (dash.length > 1) {
                                    appName = dash[dash.length - 1];
                                } else {
                                    appName = rawTitle;
                                }
                            }
                        }

                        root.activeAppTitle = appName !== "" ? appName : "Desktop";
                        return;
                    } catch(e) {
                        console.warn("[WindowService] Error parsing tracker JSON: " + e);
                    }
                }

                let parts = t.split("|");
                if (parts.length >= 4) {
                    root.isMaximized = (parts[0] === "1");
                    root.hasFullscreenApp = (parts[1] === "1");
                    let rawApp = parts[2] || "";
                    let rawTitle = parts[3] || "";
                    root.activeScreen = parts.length >= 5 ? parts[4] : "";

                    root.activeAppId = rawApp;
                    root.activeWindowTitle = rawTitle;

                    if (parts.length >= 6) {
                        try {
                            root.windowList = JSON.parse(parts[5]);
                        } catch(e) {}
                    }

                    if (parts.length >= 7) {
                        try {
                            root.virtualDesktops = JSON.parse(parts[6]);
                        } catch(e) {}
                    }

                    if (root.windowList && root.windowList.length > 0) {
                        let activeWin = root.windowList.find(function(w) { return w.active; });
                        root.activeWindowId = activeWin ? activeWin.id : "";
                        root.isFocusedWindowMaximized = activeWin ? (activeWin.maximized !== undefined ? !!activeWin.maximized : root.isMaximized) : false;
                    } else {
                        root.activeWindowId = "";
                        root.isFocusedWindowMaximized = (rawApp !== "" && rawApp !== "Desktop") ? root.isMaximized : false;
                    }

                    // Clean formatted app name
                    let appName = "";
                    if (rawApp.length > 0) {
                        let segments = rawApp.split(".");
                        let last = segments[segments.length - 1];
                        if (last.toLowerCase() === "desktop" && segments.length > 1) {
                            last = segments[segments.length - 2];
                        }
                        if (last.length > 0) {
                            appName = last.charAt(0).toUpperCase() + last.slice(1);
                        }
                    }
                    if (appName === "" && rawTitle.length > 0) {
                        let dash = rawTitle.split(" — ");
                        if (dash.length > 1) {
                            appName = dash[dash.length - 1];
                        } else {
                            dash = rawTitle.split(" - ");
                            if (dash.length > 1) {
                                appName = dash[dash.length - 1];
                            } else {
                                appName = rawTitle;
                            }
                        }
                    }

                    root.activeAppTitle = appName !== "" ? appName : "Desktop";
                }
            }
        }
    }
}
