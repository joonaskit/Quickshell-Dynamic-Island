// KWin Script to track active window, maximization, and fullscreen state for Quickshell Island

function getApp(win) {
    if (!win) return "";
    var app = win.resourceClass || win.desktopFileName || win.resourceName || "";
    return String(app);
}

function getTitle(win) {
    if (!win) return "";
    return String(win.caption || "");
}

function getScreen(win) {
    if (!win || !win.output) return "";
    return String(win.output.name || "");
}

function isMax(win) {
    if (!win) return false;
    if (win.maximizeMode === 3) return true;
    if (win.maximized === true) return true;
    return false;
}

function isFull(win) {
    if (!win) return false;
    return (win.fullScreen === true);
}

// Checks if window is on the current virtual desktop / workspace
function isOnCurrent(w) {
    if (!w) return false;
    if (typeof w.desktops !== "undefined" && typeof workspace.currentDesktop !== "undefined") {
        if (!w.desktops || w.desktops.length === 0) return true; // on all desktops
        for (var d = 0; d < w.desktops.length; d++) {
            if (w.desktops[d] === workspace.currentDesktop) {
                return true;
            }
        }
        return false;
    }
    if (typeof w.onCurrentDesktop !== "undefined") {
        return !!w.onCurrentDesktop;
    }
    if (typeof w.desktop !== "undefined" && typeof workspace.currentDesktop !== "undefined") {
        if (w.desktop === -1 || w.desktop === 0) return true; // on all desktops
        return w.desktop === workspace.currentDesktop;
    }
    return true;
}

function isIgnoredApp(app) {
    if (!app) return false;
    var a = app.toLowerCase();
    return a === "quickshell" || a === "plasmashell" || a === "org.kde.plasmashell";
}

function isTiled(win) {
    if (!win) return false;
    // Don't treat a window actively being moved or resized by the user as tiled
    if (win.move || win.resize) return false;
    // KWin QuickTileMode: 1=Left, 2=Right, 4=Top, 8=Bottom, or corners (5,6,9,10). 15 is Maximize (handled by isMax).
    if (typeof win.quickTileMode !== "undefined" && win.quickTileMode > 0 && win.quickTileMode < 15) return true;
    // KWin 6 Custom Tiling: tile exists and has a parent tile (meaning inside a split layout, not root container)
    if (win.tile && win.tile.parent) return true;
    return false;
}

// Checks if ANY visible normal window is maximized on the current virtual desktop
function anyMaximized() {
    var wins = workspace.windowList();
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && w.normalWindow !== false && !w.minimized && !w.hidden && isMax(w)) {
            if (isIgnoredApp(getApp(w))) continue;
            if (!isOnCurrent(w)) continue;
            return true;
        }
    }
    return false;
}

// Checks if ANY visible normal window is fullscreen on the current virtual desktop
function anyFullscreen() {
    var wins = workspace.windowList();
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && w.normalWindow !== false && !w.minimized && !w.hidden && isFull(w)) {
            if (isIgnoredApp(getApp(w))) continue;
            if (!isOnCurrent(w)) continue;
            return true;
        }
    }
    return false;
}

function getWindowDesktopIds(w) {
    if (!w) return [];
    var list = [];
    if (typeof w.desktops !== "undefined" && w.desktops) {
        for (var i = 0; i < w.desktops.length; i++) {
            var d = w.desktops[i];
            if (d && d.id) {
                list.push(String(d.id));
            } else if (d) {
                list.push(String(d));
            }
        }
    } else if (typeof w.desktop !== "undefined") {
        list.push(String(w.desktop));
    }
    return list;
}

function getWindowGeometry(win) {
    if (!win) return null;
    try {
        if (win.frameGeometry) {
            return {
                x: Math.round(win.frameGeometry.x || 0),
                y: Math.round(win.frameGeometry.y || 0),
                width: Math.round(win.frameGeometry.width || 0),
                height: Math.round(win.frameGeometry.height || 0)
            };
        }
        if (typeof win.x !== "undefined" && typeof win.y !== "undefined") {
            return {
                x: Math.round(win.x || 0),
                y: Math.round(win.y || 0),
                width: Math.round(win.width || 0),
                height: Math.round(win.height || 0)
            };
        }
    } catch(e) {}
    return null;
}

function getWindowSummary() {
    var wins = workspace.windowList();
    var list = [];
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && w.normalWindow !== false && !w.hidden) {
            var app = getApp(w);
            if (isIgnoredApp(app)) continue;
            var g = getWindowGeometry(w);
            list.push({
                id: String(w.internalId),
                app: app,
                title: getTitle(w),
                screen: getScreen(w),
                x: g ? g.x : 0,
                y: g ? g.y : 0,
                width: g ? g.width : 0,
                height: g ? g.height : 0,
                active: (w === workspace.activeWindow),
                minimized: !!w.minimized,
                maximized: isMax(w),
                tiled: isTiled(w),
                moving: !!(w.move || w.resize),
                fullscreen: isFull(w),
                onCurrent: isOnCurrent(w),
                desktops: getWindowDesktopIds(w)
            });
        }
    }
    try {
        return JSON.stringify(list);
    } catch(e) {
        return "[]";
    }
}

var lastSendTime = 0;
function sendStateThrottled() {
    var now = (new Date()).getTime();
    if (now - lastSendTime > 80) {
        lastSendTime = now;
        sendState();
    }
}

function sendState() {
    var anyMax = anyMaximized();
    var anyFull = anyFullscreen();
    var win = workspace.activeWindow;

    var title = "";
    var app = "";
    var scr = "";

    if (win && win.normalWindow !== false) {
        title = getTitle(win);
        app = getApp(win);
        scr = getScreen(win);
    }

    var winListJson = getWindowSummary();

    callDBus("org.quickshell.IslandBridge", "/Bridge", "org.quickshell.IslandBridge", "notifyState", anyMax, anyFull, title, app, scr, winListJson);
}

var hookedWindows = {};

function hookWindow(win) {
    if (!win) return;
    if (isIgnoredApp(getApp(win))) return;
    var id = String(win.internalId);
    if (hookedWindows[id]) return;
    hookedWindows[id] = true;

    try {
        if (win.tileChanged) {
            win.tileChanged.connect(function() {
                sendState();
            });
        }
    } catch (e) {}

    try {
        if (win.quickTileModeChanged) {
            win.quickTileModeChanged.connect(function() {
                sendState();
            });
        }
    } catch (e) {}

    try {
        if (win.frameGeometryChanged) {
            win.frameGeometryChanged.connect(function() {
                sendStateThrottled();
            });
        }
    } catch (e) {}

    try {
        if (win.interactiveMoveResizeFinished) {
            win.interactiveMoveResizeFinished.connect(function() {
                sendState();
            });
        }
    } catch (e) {}

    try {
        win.maximizedChanged.connect(function() {
            sendState();
        });
    } catch (e) {}

    try {
        win.minimizedChanged.connect(function() {
            sendState();
        });
    } catch (e) {}

    try {
        win.fullScreenChanged.connect(function() {
            sendState();
        });
    } catch (e) {}

    try {
        win.activeChanged.connect(function() {
            sendState();
        });
    } catch (e) {}

    try {
        if (win.desktopsChanged) {
            win.desktopsChanged.connect(function() {
                sendState();
            });
        }
    } catch (e) {}

    try {
        if (win.desktopChanged) {
            win.desktopChanged.connect(function() {
                sendState();
            });
        }
    } catch (e) {}
}

// Hook existing windows
var wins = workspace.windowList();
for (var i = 0; i < wins.length; i++) {
    hookWindow(wins[i]);
}

// Hook future windows
workspace.windowAdded.connect(function(win) {
    hookWindow(win);
    sendState();
});

workspace.windowActivated.connect(function(win) {
    hookWindow(win);
    sendState();
});

workspace.windowRemoved.connect(function() {
    sendState();
});

try {
    workspace.currentDesktopChanged.connect(function() {
        sendState();
    });
} catch (e) {}

try {
    if (workspace.desktopsChanged) {
        workspace.desktopsChanged.connect(function() {
            sendState();
        });
    }
} catch (e) {}

// Initial state notification
sendState();
