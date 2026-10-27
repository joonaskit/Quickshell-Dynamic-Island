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
