.pragma library

// Pure logic of the category dial launcher (see dial/DialWindow.qml). Kept free of
// Quickshell types so it can be tested with qmltestrunner (see tests/).

// Geometry at scale 1.0, in px. DialWindow multiplies every length by Theme.px().
var RING_STEP = 22;      // degrees a lone category pill turns per step; pills are spaced by width
var RING_GAP = 10;       // px between neighbouring category pills, along the ring
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

// Where each category pill sits, in degrees round the ring from the first one. Pills are
// spaced by their widths (px), `gap` px apart, so a long label does not crowd its neighbours.
function ringAngles(widths, radius, gap) {
    let angles = [];
    let at = 0;
    widths.forEach((w, i) => {
        if (i > 0) at += (widths[i - 1] / 2 + w / 2 + gap) / radius * 180 / Math.PI;
        angles.push(at);
    });
    return angles;
}

// Degrees per step off one end of the ring, for a turn that swings or is dragged past it
function ringEndStep(angles, last) {
    if (angles.length < 2) return RING_STEP;
    return last ? angles[angles.length - 1] - angles[angles.length - 2] : angles[1] - angles[0];
}

// How far the ring is turned, in degrees, when it stands at `position` steps
function ringAngleAt(angles, position) {
    if (angles.length === 0) return 0;
    let last = angles.length - 1;
    if (position <= 0) return angles[0] + position * ringEndStep(angles, false);
    if (position >= last) return angles[last] + (position - last) * ringEndStep(angles, true);
    let i = Math.floor(position);
    return angles[i] + (angles[i + 1] - angles[i]) * (position - i);
}

// The reverse: the position in steps of a ring turned by `degrees`
function ringPositionAt(angles, degrees) {
    if (angles.length === 0) return 0;
    let last = angles.length - 1;
    if (degrees <= angles[0]) return (degrees - angles[0]) / ringEndStep(angles, false);
    if (degrees >= angles[last]) return last + (degrees - angles[last]) / ringEndStep(angles, true);
    let i = 0;
    while (angles[i + 1] <= degrees) i++;
    return i + (degrees - angles[i]) / (angles[i + 1] - angles[i]);
}

// 0..1 opacity of a ring pill that is `distance` steps from the bottom slot. Whole steps
// give the prototype's values; in between it fades, so a pill dims as the ring turns.
function ringOpacity(distance) {
    if (distance <= 3) return 1;
    if (distance <= 4) return 1 - (distance - 3) * 0.65;
    return Math.max(0, 0.35 * (5 - distance));
}

// 0..1 opacity of an app tile that is `distance` steps from the bottom slot: full within
// VISIBLE_APPS, gone one step further
function arcOpacity(distance) {
    return clamp(VISIBLE_APPS + 1 - distance, 0, 1);
}

// Scrollbar thumb as the visible window of the list, in degrees along the 30..150 track.
// `focus` may be between slots while the arc turns.
function thumbSpan(focus, count) {
    if (count <= 0) return { from: 150, to: 30 };
    let first = Math.max(0, focus - VISIBLE_APPS);
    let last = Math.min(count, focus + VISIBLE_APPS + 1);
    return { from: 150 - first / count * 120, to: 150 - last / count * 120 };
}

// ----- Turning -----

var WHEEL_NOTCH = 120;   // angleDelta of one mouse wheel notch, which turns one step
var TURN_MS = 360;       // a turn of one step
var TURN_MS_PER_STEP = 40;
var TURN_MS_MAX = 900;
var TURN_OVERSHOOT = 0.9; // Easing.OutBack overshoot of a one-step turn, about 3% past the slot
var GRAB_RADIUS = 200;   // the rings can be grabbed from here out; inside is the search field and the pill
var DRAG_START = 8;      // px the pointer travels before a press becomes a drag
var DRAG_SLACK = 0.35;   // steps a ring can be dragged past its ends
var FLICK_WINDOW = 100;  // ms of pointer movement a flick's speed is measured over
var FLICK_GLIDE = 0.25;  // seconds of its release speed a flicked ring travels on

// Whole steps in a wheel delta. What is left over is carried to the next event, so the
// small deltas of a touchpad add up and a fast scroll turns further than a slow one.
function wheelSteps(carry, delta) {
    let total = carry + delta / WHEEL_NOTCH;
    let steps = total < 0 ? Math.ceil(total) : Math.floor(total);
    return { steps: steps, carry: total - steps };
}

// How long a turn across `distance` steps takes. Longer turns take longer but move faster.
function turnDuration(distance) {
    return Math.round(clamp(TURN_MS + TURN_MS_PER_STEP * (Math.abs(distance) - 1), TURN_MS, TURN_MS_MAX));
}

// Easing.OutBack overshoot of a turn across `distance` steps. A long spin settles without
// swinging past, where 3% of the way would be most of a step.
function turnOvershoot(distance) {
    return TURN_OVERSHOOT / Math.max(1, Math.abs(distance));
}

// Degrees from one pointer angle to the next, the short way round (-180..180)
function angleStep(from, to) {
    let d = (to - from) % 360;
    if (d > 180) d -= 360;
    else if (d <= -180) d += 360;
    return d;
}

// Where a dragged ring of `count` items may sit, in steps
function dragTurn(turn, count) {
    return clamp(turn, -DRAG_SLACK, Math.max(0, count - 1) + DRAG_SLACK);
}

// Speed of a drag at release, in steps per second. samples: [{ t: ms, turn: steps }],
// oldest first. Zero when the pointer rested before letting go.
function flickVelocity(samples, now) {
    let recent = samples.filter(s => now - s.t <= FLICK_WINDOW);
    if (recent.length < 2) return 0;
    let first = recent[0];
    let last = recent[recent.length - 1];
    if (last.t === first.t) return 0;
    return (last.turn - first.turn) / (last.t - first.t) * 1000;
}

// The slot a ring of `count` items comes to rest on when let go at `velocity`
function flickTarget(turn, velocity, count) {
    return clamp(Math.round(turn + velocity * FLICK_GLIDE), 0, Math.max(0, count - 1));
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
