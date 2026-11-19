.pragma library

// Settings window choices that stand for more than one saved setting. The keys stay
// separate in settings.json; the window shows them as one segmented choice. Kept free
// of Quickshell types so it can be tested with qmltestrunner (see tests/).

// A setting and a sub-setting that only applies while it is on (show and auto-hide,
// show and keep shown) as one value: "off", "on", or "sub" for both on
function pairValue(on, sub) {
    if (!on) return "off";
    return sub ? "sub" : "on";
}

// The settings to save for a pair value, as { on, sub }. Turning the pair off leaves
// the sub-setting as it was, so sub is null then
function pairSettings(value) {
    if (value === "off") return { "on": false, "sub": null };
    return { "on": true, "sub": value === "sub" };
}

// When the top bar shows: "island" (never), "maximized" (with a maximized or tiled
// window) or "always". alwaysTopBar wins over morphToTopBarWhenMaximized
function topBarMode(morphWhenMaximized, alwaysTopBar) {
    if (alwaysTopBar) return "always";
    return morphWhenMaximized ? "maximized" : "island";
}

// The settings to save for a top bar mode, as { morphToTopBarWhenMaximized, alwaysTopBar }
function topBarSettings(mode) {
    return {
        "morphToTopBarWhenMaximized": mode !== "island",
        "alwaysTopBar": mode === "always"
    };
}

// The settings the "Use niri defaults" button saves: the full-width bar always shown,
// the status icons kept in the top-right corner rather than in the dial, the virtual
// desktops pill showing niri's workspaces, and the dock hiding while a window is under
// it: niri's tiled windows fill the screen's height, and the dock reserves no space
function niriDefaults() {
    return {
        "morphToTopBarWhenMaximized": true,
        "alwaysTopBar": true,
        "autoHideTopBar": false,
        "dialStatusIcons": false,
        "showVirtualDesktops": true,
        "dockAutoHideFromWindows": true,
        "dockAutoHideAlways": false
    };
}

// Settings a first start applies, before settings.json exists: niri's defaults under niri,
// else none. Once the file is written a later start never applies them again, so a change
// the user makes afterwards stays.
function firstStartSettings(compositor) {
    return compositor === "niri" ? niriDefaults() : {};
}
