pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "niriState.js" as NiriState

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

    // What the window actions can do here. niri has no minimize and no keep above, and
    // makes and removes its workspaces itself. Callers hide what is false.
    readonly property bool niri: NiriService.active
    readonly property bool canMinimize: !root.niri
    readonly property bool canKeepAbove: !root.niri
    readonly property bool canEditDesktops: !root.niri
    readonly property string desktopNoun: root.niri ? "Workspace" : "Desktop"

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
        if (root.niri) {
            NiriService.action("FocusWorkspace", { "reference": { "Id": Number(desktopIdOrIndex) } });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.switchDesktop", String(desktopIdOrIndex)]);
    }

    function nextDesktop() {
        if (root.niri) {
            NiriService.action("FocusWorkspaceDown");
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.nextDesktop"]);
    }

    function previousDesktop() {
        if (root.niri) {
            NiriService.action("FocusWorkspaceUp");
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.previousDesktop"]);
    }

    function createDesktop(name) {
        if (!root.canEditDesktops) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.createDesktop", String(name || "")]);
    }

    function removeDesktop(desktopId) {
        if (!desktopId || !root.canEditDesktops) return;
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
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            if (id !== null) NiriService.action("FocusWindow", { "id": id });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.activateWindow", String(idOrApp)]);
    }

    function closeWindow(idOrApp) {
        if (!idOrApp) return;
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            if (id !== null) NiriService.action("CloseWindow", { "id": id });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.closeWindow", String(idOrApp)]);
    }

    function minimizeWindow(idOrApp) {
        if (!idOrApp || !root.canMinimize) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.minimizeWindow", String(idOrApp)]);
    }

    function maximizeWindow(idOrApp) {
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            if (id !== null && !root.niriIsMaximized(id)) NiriService.action("MaximizeWindowToEdges", { "id": id });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.maximizeWindow", String(idOrApp || "")]);
    }

    function unmaximizeWindow(idOrApp) {
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            if (id !== null && root.niriIsMaximized(id)) NiriService.action("MaximizeWindowToEdges", { "id": id });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.unmaximizeWindow", String(idOrApp || "")]);
    }

    function toggleMaximize(idOrApp) {
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            if (id !== null) NiriService.action("MaximizeWindowToEdges", { "id": id });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.toggleMaximizeWindow", String(idOrApp || "")]);
    }

    function toggleKeepAbove(idOrApp) {
        if (!idOrApp || !root.canKeepAbove) return;
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.toggleKeepAbove", String(idOrApp)]);
    }

    function moveToNextDesktop(idOrApp) {
        if (!idOrApp) return;
        if (root.niri) {
            let id = root.niriWindowId(idOrApp);
            let target = id === null ? null : NiriState.nextWorkspaceFor(NiriService.state, id);
            if (target !== null) NiriService.action("MoveWindowToWorkspace", { "window_id": id, "reference": { "Id": target }, "focus": false });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.moveToNextDesktop", String(idOrApp)]);
    }

    function quitApplication(idOrApp) {
        if (!idOrApp) return;
        if (root.niri) {
            let ids = NiriState.windowIdsOfApp(NiriService.state, String(idOrApp));
            for (let i = 0; i < ids.length; i++) NiriService.action("CloseWindow", { "id": ids[i] });
            return;
        }
        Quickshell.execDetached(["qdbus-qt6", "org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge.quitApplication", String(idOrApp)]);
    }

    // niri's id for a window id or app id as the callers pass them: a window id as
    // trackedWindows gives it, else the focused window of that app, else its first
    function niriWindowId(idOrApp) {
        let w = NiriState.windowById(NiriService.state, idOrApp);
        if (w) return w.id;
        let ids = NiriState.windowIdsOfApp(NiriService.state, String(idOrApp || ""));
        let focused = NiriService.focusedWindow;
        if (focused && ids.indexOf(focused.id) >= 0) return focused.id;
        return ids.length > 0 ? ids[0] : (focused ? focused.id : null);
    }

    // niri sends no maximized flag; the focused window's comes from its toplevel
    function niriIsMaximized(id) {
        let focused = NiriService.focusedWindow;
        return !!focused && focused.id === id && root.isMaximized;
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

    // The desktop's settings app: KDE's System Settings, under niri niri-settings, else
    // whichever of the two is installed, else the shell's own settings window
    function openSettings() {
        let kde = !DepsService.noneUsable(["systemsettings"]);
        let niri = !DepsService.noneUsable(["niri-settings"]);
        if (root.niri && niri) root.openNiriSettings("");
        else if (kde) launchCommand(["systemsettings"], "systemsettings");
        else if (niri) root.openNiriSettings("");
        else SettingsService.requestOpenSettings("", "");
    }

    // Opens niri-settings, at a page by its id ("binds", "layer-rules"...) when it is given
    // and the installed niri-settings knows --page
    function openNiriSettings(page) {
        launchCommand(["sh", "-c",
            "if [ -n \"$1\" ] && niri-settings --help 2>/dev/null | grep -q -- --page; then " +
            "exec niri-settings --page \"$1\"; else exec niri-settings; fi", "sh", String(page || "")],
            "io.github.joonaskit.NiriSettings");
    }

    function lockScreen() {
        PowerService.lock();
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
        // check=true: an unknown name gives "" instead of Qt's missing-icon checkerboard
        let p = Quickshell.iconPath(iconName, true);
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
        return resolveIconSource(iconName);
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
    // compositors with wlr-foreign-toplevel-management). Under niri the window list, the
    // focused window's id and its screen come from NiriService, which also knows the
    // workspaces; elsewhere there is no window list and DockService reads the toplevels.
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
        if (root.niri && NiriService.focusedOutput !== "") screen = NiriService.focusedOutput;
        if (screen !== "") root.activeScreen = screen;
    }

    function syncNiri() {
        root.windowList = NiriState.trackedWindows(NiriService.state);
        let focused = NiriService.focusedWindow;
        root.activeWindowId = focused ? String(focused.id) : "";
        if (NiriService.focusedOutput !== "") root.activeScreen = NiriService.focusedOutput;
    }

    Connections {
        target: root.niri ? NiriService : null
        function onWindowsChanged() { root.syncNiri(); }
        function onWorkspacesChanged() { root.syncNiri(); }
        function onFocusedOutputChanged() { root.syncNiri(); }
    }

    // Untyped, because qmllint cannot resolve the type of Toplevel.screens
    function firstScreenName(toplevel) {
        let screens = toplevel.screens;
        return screens && screens.length > 0 ? screens[0].name : "";
    }

    Component.onCompleted: {
        if (root.niri) root.syncNiri();
        if (!CompositorService.isKde) root.syncToplevel();
    }

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
