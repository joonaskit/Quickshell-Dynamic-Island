pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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

    // Until when a desktop change comes from a click on the virtual desktops pill
    property double pillSwitchUntil: 0

    function switchToDesktop(desktopIdOrIndex) {
        if (desktopIdOrIndex === undefined || desktopIdOrIndex === null) return;
        root.pillSwitchUntil = Date.now() + 800;
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

    // systemd scope name for an app, per the desktop environment cgroup convention
    function appScopeName(appId) {
        let id = String(appId || "").replace(/\.desktop$/, "") || "app";
        let escaped = id.replace(/[^A-Za-z0-9_.:]/g, function(c) {
            return "\\x" + c.charCodeAt(0).toString(16).padStart(2, "0");
        });
        return "app-" + escaped + "-" + Math.random().toString(16).slice(2, 10) + ".scope";
    }

    // Launch a command in its own systemd scope so it is not accounted to the shell's cgroup
    function launchCommand(command, appId, workingDirectory) {
        if (!command || command.length === 0) return;
        let script = "unit=\"$1\"; dir=\"$2\"; shift 2; " +
                     "[ -n \"$dir\" ] && cd \"$dir\" 2>/dev/null; " +
                     "if command -v systemd-run >/dev/null 2>&1; then " +
                     "exec systemd-run --user --scope --quiet --collect --slice=app.slice --unit=\"$unit\" -- \"$@\"; " +
                     "else exec \"$@\"; fi";
        let argv = ["sh", "-c", script, "sh", appScopeName(appId), workingDirectory || ""];
        for (let i = 0; i < command.length; i++) argv.push(String(command[i]));
        Quickshell.execDetached(argv);
    }

    // Launch a command in a terminal: Konsole under KDE, else xdg-terminal-exec, $TERMINAL
    // or the first common terminal found
    function launchInTerminal(command, appId, workingDirectory) {
        if (!command || command.length === 0) return;
        let script = (CompositorService.isKde ? "command -v konsole >/dev/null 2>&1 && exec konsole -e \"$@\"; " : "") +
                     "command -v xdg-terminal-exec >/dev/null 2>&1 && exec xdg-terminal-exec \"$@\"; " +
                     "for t in \"$TERMINAL\" konsole foot alacritty kitty ghostty wezterm gnome-terminal xterm; do " +
                     "[ -n \"$t\" ] && command -v \"$t\" >/dev/null 2>&1 && exec \"$t\" -e \"$@\"; done";
        let argv = ["sh", "-c", script, "sh"];
        launchCommand(argv.concat(command), appId, workingDirectory);
    }

    // Launch a DesktopEntry or one of its DesktopActions (appId names the owning entry)
    function launchEntry(entry, appId) {
        if (!entry) return;
        let command = entry.command;
        if (command && command.length > 0) {
            launchCommand(command, appId || entry.id, entry.workingDirectory);
        } else {
            entry.execute();
        }
    }

    function launchNewWindow(appId) {
        if (!appId) return;
        let cleanId = appId.replace(/\.desktop$/, "");
        let entry = DesktopEntries.byId(cleanId);
        if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
        if (entry) {
            launchEntry(entry);
            return;
        }
        launchCommand(["gtk-launch", appId.endsWith(".desktop") ? appId : (appId + ".desktop")], cleanId);
    }

    function openTerminal() {
        let entry = DesktopEntries.byId("org.kde.konsole");
        if (entry) {
            launchEntry(entry);
            return;
        }
        launchCommand(["sh", "-c", "konsole || x-terminal-emulator || alacritty || kitty || gnome-terminal"], "terminal");
    }

    function openFileManager() {
        // Default file manager, falling back to Dolphin
        launchCommand(["sh", "-c",
            "fm=$(xdg-mime query default inode/directory); " +
            "if [ -n \"$fm\" ] && command -v gtk-launch >/dev/null 2>&1; then exec gtk-launch \"$fm\"; " +
            "else exec dolphin; fi"], "file-manager");
    }

    function openSettings() {
        launchCommand(["systemsettings"], "systemsettings");
    }

    function lockScreen() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    // Resolve an icon name or path to an image source, or "" if not found
    function resolveIconSource(iconName) {
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
            return "file://" + p;
        }
        return "";
    }

    function resolveAppIcon(appId) {
        if (!appId || appId.length === 0) return "";
        let cleanId = appId.replace(/\.desktop$/, "");
        let entry = DesktopEntries.byId(cleanId);
        if (!entry) entry = DesktopEntries.heuristicLookup(cleanId);
        let iconName = entry ? entry.icon : appId;
        if (!iconName || iconName.length === 0) return "";
        return resolveIconSource(iconName) || ("image://icon/" + iconName);
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

    // The app's name for the pill: the last part of its id, else the end of the window title
    function appTitle(rawApp, rawTitle) {
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
                appName = dash.length > 1 ? dash[dash.length - 1] : rawTitle;
            }
        }
        return appName !== "" ? appName : "Desktop";
    }

    // Outside KWin the active window comes from the Wayland toplevel list (niri and other
    // compositors with wlr-foreign-toplevel-management). There is no window list or
    // virtual desktops here: DockService reads the toplevels itself.
    function syncToplevel() {
        let t = ToplevelManager.activeToplevel;
        let active = !!t && t.activated;
        let app = active ? (t.appId || "") : "";
        let title = active ? (t.title || "") : "";
        root.isMaximized = active && t.maximized;
        root.isFocusedWindowMaximized = root.isMaximized;
        root.hasFullscreenApp = active && t.fullscreen;
        root.activeAppId = app;
        root.activeWindowTitle = title;
        root.activeAppTitle = root.appTitle(app, title);
        // The last screen with a focused window, so the dial still knows where to open
        let screen = active ? root.firstScreenName(t) : "";
        if (screen !== "") root.activeScreen = screen;
    }

    // Untyped, because qmllint cannot resolve the type of Toplevel.screens
    function firstScreenName(toplevel) {
        let screens = toplevel.screens;
        return screens && screens.length > 0 ? screens[0].name : "";
    }

    Component.onCompleted: if (!CompositorService.isKde) root.syncToplevel()

    Connections {
        target: CompositorService.isKde ? null : ToplevelManager
        function onActiveToplevelChanged() { root.syncToplevel(); }
    }

    Connections {
        target: CompositorService.isKde ? null : ToplevelManager.activeToplevel
        function onActivatedChanged() { root.syncToplevel(); }
        function onAppIdChanged() { root.syncToplevel(); }
        function onTitleChanged() { root.syncToplevel(); }
        function onMaximizedChanged() { root.syncToplevel(); }
        function onFullscreenChanged() { root.syncToplevel(); }
        function onScreensChanged() { root.syncToplevel(); }
    }

    HelperProcess {
        id: trackerProc
        helperId: "windows"
        helperName: "Window tracker"
        restartDelay: 1000
        command: ["python3", Quickshell.shellDir + "/scripts/kwin_window_tracker.py"]
        // It loads a KWin script, so it is only started under KWin
        wanted: CompositorService.isKde

        stdout: SplitParser {
            onRead: function(line) {
                let t = line.trim();
                if (t === "LAUNCHER_TOGGLE") {
                    DockService.toggleLauncher("");
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

                        root.activeAppTitle = root.appTitle(rawApp, rawTitle);
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

                    root.activeAppTitle = root.appTitle(rawApp, rawTitle);
                }
            }
        }
    }
}
