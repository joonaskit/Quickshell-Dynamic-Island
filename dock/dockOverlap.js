.pragma library

// Whether an open window covers the dock, for "Auto-hide when windows overlap". Kept
// free of Quickshell types so it can be tested with qmltestrunner (tests/tst_dockOverlap.qml).

// The dock's box in global coordinates: screen is { x, y, width, height }, position
// "bottom", "left" or "right", length the dock's long side and depth its short side
function dockRect(screen, position, length, depth) {
    if (position === "left") {
        let top = screen.y + (screen.height - length) / 2;
        return { "left": screen.x, "right": screen.x + depth, "top": top, "bottom": top + length };
    }
    if (position === "right") {
        let top = screen.y + (screen.height - length) / 2;
        return { "left": screen.x + screen.width - depth, "right": screen.x + screen.width, "top": top, "bottom": top + length };
    }
    let left = screen.x + (screen.width - length) / 2;
    return { "left": left, "right": left + length, "top": screen.y + screen.height - depth, "bottom": screen.y + screen.height };
}

// Apps whose windows are the desktop's own UI, never counted
var SHELL_APPS = ["quickshell", "plasmashell", "org.kde.plasmashell"];

// windows are WindowService.windowList entries; screen is { name, x, y, width, height }
function overlaps(windows, screen, rect) {
    if (!windows) return false;
    for (let i = 0; i < windows.length; i++) {
        let w = windows[i];
        if (!w || w.minimized || w.onCurrent === false) continue;
        if (SHELL_APPS.indexOf(String(w.app || "").toLowerCase()) >= 0) continue;
        // A window tied to another display does not count
        if (w.screen && screen.name && w.screen !== screen.name) continue;

        // A maximized window, or one of niri's tiled ones (they fill the working area's
        // height, and their position is not sent), covers the dock
        if (w.maximized || w.spansHeight) return true;

        let ww = w.width || 0;
        let wh = w.height || 0;
        if (ww <= 0 || wh <= 0) continue;
        let wx = w.x || 0;
        let wy = w.y || 0;
        // Positions relative to the screen (niri's floating windows) made global
        if (screen.x > 0 && wx < screen.x && (wx + ww) <= screen.width) wx += screen.x;
        if (screen.y > 0 && wy < screen.y && (wy + wh) <= screen.height) wy += screen.y;

        if (!(wx + ww <= rect.left || wx >= rect.right || wy + wh <= rect.top || wy >= rect.bottom)) return true;
    }
    return false;
}
