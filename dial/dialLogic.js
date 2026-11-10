.pragma library

// Pure logic of the category dial launcher (see dial/DialWindow.qml). Kept free of
// Quickshell types so it can be tested with qmltestrunner (see tests/).

// Geometry at scale 1.0, in px. DialWindow multiplies every length by Theme.px().
var RING_STEP = 22;      // degrees between category pills
var ARC_STEP = 13;       // degrees between app tiles
var RING_RADIUS = 230;
var ARC_RADIUS = 345;
var BAR_RADIUS = 285;
var DISC_RADIUS = 400;
var TURN_RADIUS = 288;   // wheel inside this turns the ring, outside the arc
var VISIBLE_APPS = 4;    // neighbours each side of the bottom slot
var BAR_MIN_ITEMS = 9;   // the arc scrollbar shows above this many items

// Ring entries in order. "group" ones list the apps of their freedesktop categories.
var CATEGORIES = [
    { name: "Pinned", kind: "pinned" },
    { name: "All", kind: "all" },
    { name: "Recent", kind: "recent" },
    { name: "Frequent", kind: "frequent" },
    { name: "Internet", kind: "group", sources: ["Network", "WebBrowser", "Email", "InstantMessaging", "Chat"] },
    { name: "Development", kind: "group", sources: ["Development"] },
    { name: "Multimedia", kind: "group", sources: ["AudioVideo", "Audio", "Video", "Player", "Recorder"] },
    { name: "Graphics", kind: "group", sources: ["Graphics"] },
    { name: "Office", kind: "group", sources: ["Office"] },
    { name: "System", kind: "group", sources: ["System", "Settings", "Monitor", "PackageManager"] },
    { name: "Utilities", kind: "group", sources: ["Utility", "Accessibility"] }
];

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// The group an app belongs to: the first of its categories that maps to one, else Utilities.
function groupOf(categories) {
    for (let i = 0; i < categories.length; i++) {
        for (let c = 0; c < CATEGORIES.length; c++) {
            if (CATEGORIES[c].kind === "group" && CATEGORIES[c].sources.indexOf(categories[i]) >= 0)
                return CATEGORIES[c].name;
        }
    }
    return "Utilities";
}

var HISTORY_LIMIT = 16;  // Recent and Frequent show this many, as the dock launcher does

// Items of one ring entry. apps: [{ id, name, categories }], pinnedIds: ids in pin order,
// usage: { appId: { count, last } } from the dock launcher's launch history.
function itemsFor(category, apps, pinnedIds, usage) {
    usage = usage || {};
    let sorted = apps.slice().sort((a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0);
    let def = CATEGORIES[clamp(category, 0, CATEGORIES.length - 1)];
    if (def.kind === "all") return sorted;
    if (def.kind === "group") return sorted.filter(a => groupOf(a.categories) === def.name);
    if (def.kind === "pinned") {
        let byId = {};
        apps.forEach(a => { byId[a.id] = a; });
        return pinnedIds.filter(id => byId[id]).map(id => byId[id]);
    }
    let used = apps.filter(a => usage[a.id]);
    if (def.kind === "recent")
        used.sort((a, b) => usage[b.id].last - usage[a.id].last);
    else
        used.sort((a, b) => (usage[b.id].count - usage[a.id].count) || (usage[b.id].last - usage[a.id].last));
    return used.slice(0, HISTORY_LIMIT);
}

// The slot an app arc opens on: the middle of the list
function middle(count) {
    return Math.floor((count - 1) / 2);
}

// Position on a circle around the pill centre; 90 degrees is straight down.
function point(radius, degrees) {
    let r = degrees * Math.PI / 180;
    return { x: radius * Math.cos(r), y: radius * Math.sin(r) };
}

// 0..1 opacity of a ring pill that is `distance` steps from the selected one
function ringOpacity(distance) {
    return distance <= 3 ? 1 : distance === 4 ? 0.35 : 0;
}

// Scrollbar thumb as the visible window of the list, in degrees along the 30..150 track
function thumbSpan(focus, count) {
    if (count <= 0) return { from: 150, to: 30 };
    let first = Math.max(0, focus - VISIBLE_APPS);
    let last = Math.min(count, focus + VISIBLE_APPS + 1);
    return { from: 150 - first / count * 120, to: 150 - last / count * 120 };
}

// Wheel steps are one per 140 ms, as in the prototype; returns +1 or -1
function wheelDirection(deltaY, deltaX) {
    return (deltaY || deltaX) > 0 ? 1 : -1;
}

// ----- Search -----

var SCOPES = ["Everything", "Apps", "Settings", "Files"];
var HIT_LIMIT = 40;      // hits placed on the arc
var SEARCH_FILES_MIN = 3; // characters before files are searched
var SEARCH_SETTINGS_MIN = 2;

// 0 name starts with the query, 1 contains it, 2 does not
function nameRank(name, query) {
    let at = name.toLowerCase().indexOf(query);
    return at === 0 ? 0 : (at > 0 ? 1 : 2);
}

// Apps matching the query, best first. Name matches come before generic-name ones. Among
// those, pinned apps lead, then launched ones, most used first, then the rest; within each
// of these a name prefix beats a substring, and ties go alphabetically. So the apps the
// user reaches for win over a closer but unused spelling.
// usage is { appId: { count, last } }, pinnedIds the ids pinned in the dial.
function matchApps(apps, query, usage, pinnedIds) {
    let q = (query || "").trim().toLowerCase();
    if (q === "") return [];
    usage = usage || {};
    pinnedIds = pinnedIds || [];
    let scored = [];
    apps.forEach(a => {
        let rank = nameRank(a.name, q);
        if (rank === 2 && (a.genericName || "").toLowerCase().indexOf(q) < 0) return;
        scored.push({
            "app": a,
            "rank": rank,
            "pinned": rank < 2 && pinnedIds.indexOf(a.id) >= 0 ? 0 : 1,
            "count": rank < 2 && usage[a.id] ? usage[a.id].count : 0
        });
    });
    scored.sort((x, y) => ((x.rank === 2) - (y.rank === 2))
        || (x.pinned - y.pinned)
        || (y.count - x.count)
        || (x.rank - y.rank)
        || x.app.name.localeCompare(y.app.name));
    return scored.map(s => s.app);
}

// The hits of one scope. Everything puts the apps, settings and files together, name
// prefixes first and each source keeping its own order otherwise.
function scopeHits(scope, query, apps, settings, files) {
    let q = (query || "").trim().toLowerCase();
    let list;
    if (scope === 1) list = apps;
    else if (scope === 2) list = settings;
    else if (scope === 3) list = files;
    else {
        let all = apps.concat(settings, files);
        list = all.map((h, i) => ({ "h": h, "i": i }))
            .sort((x, y) => (nameRank(x.h.name, q) === 0 ? 0 : 1) - (nameRank(y.h.name, q) === 0 ? 0 : 1) || x.i - y.i)
            .map(x => x.h);
    }
    return list.slice(0, HIT_LIMIT);
}

// Best hit in the middle, the rest alternating to its right and left, so the bottom
// slot holds the best match and the next two sit beside it.
function arrange(hits) {
    let list = [];
    hits.forEach((h, k) => {
        if (k % 2) list.push(h);
        else list.unshift(h);
    });
    return list;
}

function scopeLabels(apps, settings, files) {
    let counts = [apps.length + settings.length + files.length, apps.length, settings.length, files.length];
    return SCOPES.map((name, i) => name + " " + counts[i]);
}
