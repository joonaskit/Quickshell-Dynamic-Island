.pragma library

// Display modes for the "60 Hz on battery" setting. Takes the outputs of `kscreen-doctor -j`
// and is kept free of Quickshell types so it can be tested with qmltestrunner (see tests/).

// kscreen's output type for a built-in laptop panel
var PANEL = 7;
var BATTERY_HZ = 60;

function findMode(output, id) {
    let modes = output.modes || [];
    for (let i = 0; i < modes.length; i++) {
        if (String(modes[i].id) === String(id)) return modes[i];
    }
    return null;
}

function sameSize(a, b) {
    return a.size.width === b.size.width && a.size.height === b.size.height;
}

// The id of the mode at the current size whose rate is nearest 60 Hz, or "" when it is not slower than the current one
function batteryMode(output) {
    let cur = findMode(output, output.currentModeId);
    if (!cur) return "";
    let best = null;
    let modes = output.modes || [];
    for (let i = 0; i < modes.length; i++) {
        let m = modes[i];
        if (!sameSize(m, cur) || m.refreshRate >= cur.refreshRate) continue;
        if (!best || Math.abs(m.refreshRate - BATTERY_HZ) < Math.abs(best.refreshRate - BATTERY_HZ)) best = m;
    }
    if (!best || Math.round(cur.refreshRate) <= BATTERY_HZ) return "";
    return String(best.id);
}

// The id of the mode to go back to on AC, or "" to stay. The remembered mode wins while it is at the
// current size. Without one (the shell restarted on battery), a panel at 60 Hz goes to its fastest mode.
function acMode(output, rememberedId) {
    let cur = findMode(output, output.currentModeId);
    if (!cur) return "";
    let remembered = rememberedId ? findMode(output, rememberedId) : null;
    if (remembered && sameSize(remembered, cur)) return remembered.id === cur.id ? "" : String(remembered.id);
    if (Math.round(cur.refreshRate) > BATTERY_HZ) return "";
    let fastest = cur;
    let modes = output.modes || [];
    for (let i = 0; i < modes.length; i++) {
        if (sameSize(modes[i], cur) && modes[i].refreshRate > fastest.refreshRate) fastest = modes[i];
    }
    return fastest === cur ? "" : String(fastest.id);
}

// Which built-in panels to switch and to which mode. Returns { changes: [{ name, modeId }], remembered },
// where remembered maps each lowered panel's name to the mode it had before.
function plan(outputs, lower, remembered) {
    let changes = [];
    let kept = {};
    for (let i = 0; i < outputs.length; i++) {
        let o = outputs[i];
        if (o.type !== PANEL || !o.enabled || !o.connected) continue;
        let id = lower ? batteryMode(o) : acMode(o, remembered[o.name]);
        if (id) changes.push({ "name": o.name, "modeId": id });
        if (!lower) continue;
        if (remembered[o.name]) kept[o.name] = remembered[o.name];
        else if (id) kept[o.name] = String(o.currentModeId);
    }
    return { "changes": changes, "remembered": kept };
}

// Arguments for kscreen-doctor that apply the changes
function commandArgs(changes) {
    return changes.map(c => "output." + c.name + ".mode." + c.modeId);
}
