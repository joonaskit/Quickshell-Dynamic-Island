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

// Rates are compared loosely, as panels report values like 59.88
function sameRate(a, b) {
    return Math.abs(a - b) < 1;
}

// The id of the mode to go back to on AC, or "" to stay. `entry` is the panel's { from, to } rates. A panel
// no longer at `to` was changed by hand, and one without an entry was never lowered: both stay as they are.
function acMode(output, entry) {
    let cur = findMode(output, output.currentModeId);
    if (!cur || !entry || !sameRate(cur.refreshRate, entry.to)) return "";
    let best = cur;
    let modes = output.modes || [];
    for (let i = 0; i < modes.length; i++) {
        let m = modes[i];
        if (sameSize(m, cur) && Math.abs(m.refreshRate - entry.from) < Math.abs(best.refreshRate - entry.from)) best = m;
    }
    return best === cur ? "" : String(best.id);
}

// Which built-in panels to switch and to which mode. Returns { changes: [{ name, modeId }], remembered },
// where remembered maps each lowered panel's name to { from, to }, the rates before and after. Entries of
// panels skipped here are kept, so a panel that is off for now (lid closed) is still restored later.
function plan(outputs, lower, remembered) {
    let changes = [];
    let kept = Object.assign({}, remembered);
    for (let i = 0; i < outputs.length; i++) {
        let o = outputs[i];
        if (o.type !== PANEL || !o.enabled || !o.connected) continue;
        let entry = remembered[o.name];
        let id = lower ? batteryMode(o) : acMode(o, entry);
        if (id) changes.push({ "name": o.name, "modeId": id });
        if (!lower) {
            delete kept[o.name];
        } else if (id) {
            let from = entry ? entry.from : findMode(o, o.currentModeId).refreshRate;
            kept[o.name] = { "from": from, "to": findMode(o, id).refreshRate };
        }
    }
    return { "changes": changes, "remembered": kept };
}

// The remembered rates from the state file's text, leaving out anything malformed
function parseRemembered(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return {};
    }
    let kept = {};
    for (let name in data || {}) {
        let entry = data[name];
        if (entry && typeof entry.from === "number" && typeof entry.to === "number") kept[name] = entry;
    }
    return kept;
}

// Arguments for kscreen-doctor that apply the changes
function commandArgs(changes) {
    return changes.map(c => "output." + c.name + ".mode." + c.modeId);
}
