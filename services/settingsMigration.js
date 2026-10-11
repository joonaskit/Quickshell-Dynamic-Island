.pragma library

// Reading of settings.json formats older than the current one, used by
// SettingsService.applySettings. Kept free of Quickshell types so it can be
// tested with qmltestrunner (see tests/).

// Per-widget keys used before the "widgets" map
const legacyWidgetKeys = {
    "calendar": "showExpandedCalendar",
    "timer": "showExpandedTimer",
    "media": "showExpandedMedia",
    "audioOutput": "showExpandedAudioSink",
    "appMixer": "showExpandedAppMixer",
    "volume": "showExpandedVolume",
    "brightness": "showExpandedBrightness"
};

// Returns { id: enabled } for the widgets in `widgetIds` that have a saved
// state in `data` (the parsed settings.json). The "widgets" map wins over a
// legacy key; widgets with neither are left out so the registry default applies.
function widgetStates(data, widgetIds) {
    let states = {};
    if (!data || typeof data !== "object") return states;
    let saved = (data.widgets && typeof data.widgets === "object") ? data.widgets : {};
    for (let i = 0; i < widgetIds.length; i++) {
        let id = widgetIds[i];
        let legacyKey = legacyWidgetKeys[id];
        if (saved[id] !== undefined) states[id] = !!saved[id];
        else if (legacyKey && data[legacyKey] !== undefined) states[id] = !!data[legacyKey];
    }
    return states;
}

// The three functions below serve every user-ordered list: the expanded island
// widgets ("widgetOrder") and the status-bar icons ("statusIconOrder").

// Returns `ids` (the registry's ids) in display order. `saved` is the order
// list from settings.json: its known ids come first, in saved order, and the
// rest follow in `ids` order, so an entry added later goes at the end.
function savedOrder(saved, ids) {
    let order = [];
    if (Array.isArray(saved)) {
        for (let i = 0; i < saved.length; i++) {
            let id = saved[i];
            if (ids.indexOf(id) >= 0 && order.indexOf(id) < 0) order.push(id);
        }
    }
    for (let i = 0; i < ids.length; i++) {
        if (order.indexOf(ids[i]) < 0) order.push(ids[i]);
    }
    return order;
}

// Index in `order` of the entry that `id` would swap with when moved up
// (delta -1) or down (delta 1): the nearest one in the same group, from
// `groups` ({ id: group }). Returns -1 when there is none.
function moveTarget(order, id, delta, groups) {
    let from = order.indexOf(id);
    if (from < 0 || (delta !== 1 && delta !== -1)) return -1;
    for (let i = from + delta; i >= 0 && i < order.length; i += delta) {
        if (groups[order[i]] === groups[id]) return i;
    }
    return -1;
}

// Returns a copy of `order` with `id` moved one place up or down within its
// group, or unchanged when it is already first or last there.
function movedOrder(order, id, delta, groups) {
    let moved = order.slice();
    let to = moveTarget(order, id, delta, groups);
    if (to < 0) return moved;
    let from = order.indexOf(id);
    moved[from] = order[to];
    moved[to] = id;
    return moved;
}
