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
    { name: "Windows", kind: "windows" },
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

// Index of the ring entry of a kind ("pinned", "windows", ...), or -1
function categoryIndex(kind) {
    return CATEGORIES.findIndex(c => c.kind === kind);
}

// Items of one ring entry. apps: [{ id, name, categories }], pinnedIds: ids in pin order,
// usage: { appId: { count, last } } from the dock launcher's launch history, windows: the
// open windows, already shaped as items, for the Windows entry.
function itemsFor(category, apps, pinnedIds, usage, windows) {
    usage = usage || {};
    let def = CATEGORIES[clamp(category, 0, CATEGORIES.length - 1)];
    if (def.kind === "windows") return windows || [];
    let sorted = apps.slice().sort((a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0);
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

// The slot a navigation key moves the arc to from `focus` in a list of `count`. Home and
// End go to the ends, PageUp and PageDown a visible side's worth of tiles. key: "home",
// "end", "pageUp" or "pageDown".
function jumpTarget(key, focus, count) {
    let last = Math.max(0, count - 1);
    if (key === "home") return 0;
    if (key === "end") return last;
    if (key === "pageUp") return clamp(focus - VISIBLE_APPS, 0, last);
    if (key === "pageDown") return clamp(focus + VISIBLE_APPS, 0, last);
    return clamp(focus, 0, last);
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
// those, running apps lead, then pinned ones, then launched ones, most used first, then the
// rest; within each of these a name prefix beats a substring, and ties go alphabetically.
// So the apps the user reaches for win over a closer but unused spelling.
// usage is { appId: { count, last } }, pinnedIds the ids pinned in the dial, running
// { appId: true } for the apps with an open window.
function matchApps(apps, query, usage, pinnedIds, running) {
    let q = (query || "").trim().toLowerCase();
    if (q === "") return [];
    usage = usage || {};
    pinnedIds = pinnedIds || [];
    running = running || {};
    let scored = [];
    apps.forEach(a => {
        let rank = nameRank(a.name, q);
        if (rank === 2 && (a.genericName || "").toLowerCase().indexOf(q) < 0) return;
        scored.push({
            "app": a,
            "rank": rank,
            "running": rank < 2 && running[a.id] ? 0 : 1,
            "pinned": rank < 2 && pinnedIds.indexOf(a.id) >= 0 ? 0 : 1,
            "count": rank < 2 && usage[a.id] ? usage[a.id].count : 0
        });
    });
    scored.sort((x, y) => ((x.rank === 2) - (y.rank === 2))
        || (x.running - y.running)
        || (x.pinned - y.pinned)
        || (y.count - x.count)
        || (x.rank - y.rank)
        || x.app.name.localeCompare(y.app.name));
    return scored.map(s => s.app);
}

// The hits of one scope. Everything lists the apps first, then settings, then files, as
// this is mostly an app launcher; within settings and files name prefixes come first.
function scopeHits(scope, query, apps, settings, files) {
    let q = (query || "").trim().toLowerCase();
    let list;
    if (scope === 1) list = apps;
    else if (scope === 2) list = settings;
    else if (scope === 3) list = files;
    else {
        let rest = settings.concat(files)
            .map((h, i) => ({ "h": h, "i": i }))
            .sort((x, y) => (nameRank(x.h.name, q) === 0 ? 0 : 1) - (nameRank(y.h.name, q) === 0 ? 0 : 1) || x.i - y.i)
            .map(x => x.h);
        list = apps.concat(rest);
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

// --- Status pages ---
// A status icon's menu can be a page of the dial: its own ring, arc and readout in place
// of the launcher's. What a page cannot hold (a text field) goes in a sheet over the disc (dial/DialSheet.qml).
var PAGE_OF_ICON = { "battery": "power", "profile": "power", "wifi": "wifi", "bluetooth": "bluetooth", "hardware": "hardware", "mic": "mic",
    "nightLight": "nightLight", "hue": "hue", "notification": "notification", "clipboard": "clipboard",
    "kdeConnect": "kdeConnect", "usb": "usb", "gameMode": "gameMode" };

function pageFor(iconId) {
    return PAGE_OF_ICON[iconId] || "";
}

// Power profiles on the power page's ring, in power-profiles-daemon's names
var PROFILES = [
    { "id": "power-saver", "name": "Power Saver" },
    { "id": "balanced", "name": "Balanced" },
    { "id": "performance", "name": "Performance" }
];

function profileIndex(id) {
    let i = PROFILES.findIndex(p => p.id === id);
    return i >= 0 ? i : 1;
}

// The power page's arc. `confirm` actions run on a second click, `toggle` ones flip a
// setting and leave the dial open. `tint` is a Theme colour name.
var POWER_ACTIONS = [
    { "kind": "action", "id": "lowRefresh", "name": "60 Hz", "sub": "On battery", "icon": "battery", "tint": "accentGreen", "toggle": true },
    { "kind": "action", "id": "settings", "name": "Settings", "icon": "settings", "tint": "accentBlue" },
    { "kind": "action", "id": "lock", "name": "Lock", "icon": "lock", "tint": "accentBlue" },
    { "kind": "action", "id": "sleep", "name": "Sleep", "icon": "moon", "tint": "accentIndigo" },
    { "kind": "action", "id": "restart", "name": "Restart", "icon": "restart", "tint": "accentOrangeStrong", "confirm": true },
    { "kind": "action", "id": "shutdown", "name": "Shut Down", "icon": "power", "tint": "accentRed", "confirm": true }
];

var CONFIRM_MS = 3000;   // how long a confirm action waits for its second click

// The arc's starting slot on a page with these `items`: Lock on the power page, the
// connected network (else the strongest) on the Wi-Fi page
function pageFocus(page, items) {
    if (page === "power") return items.findIndex(a => a.id === "lock");
    if (page === "hardware") return items.length > 1 ? 1 : 0;
    if (page === "wifi" || page === "bluetooth" || page === "mic") {
        let connected = items.findIndex(a => a.inUse);
        if (connected >= 0) return connected;
        let first = items.findIndex(a => a.network || a.device || a.source);
        return first >= 0 ? first : 0;
    }
    // The pages of dialPages.js mark their starting tile
    return Math.max(0, items.findIndex(a => a.start));
}

// The Wi-Fi page's ring: the radio off or on
var WIFI_RING = ["Wi-Fi Off", "Wi-Fi On"];

// The Wi-Fi page's arc: Settings and Rescan, then the networks as NetworkService lists
// them (connected first, then by signal). Choosing a network connects to it, after asking
// for the password when it is secured and not in `saved` (SSIDs).
function wifiItems(networks, enabled, saved) {
    saved = saved || [];
    let list = [{ "kind": "action", "id": "wifiSettings", "name": "Settings", "icon": "settings", "tint": "accentBlue" }];
    if (!enabled) return list;
    list.push({ "kind": "action", "id": "rescan", "name": "Rescan", "icon": "refresh", "tint": "accentBlue" });
    return list.concat(networks.map(n => ({
        "kind": "action",
        "id": "net:" + n.ssid,
        "network": n.ssid,
        "inUse": !!n.inUse,
        "secure": !!n.isSecure,
        "saved": saved.indexOf(n.ssid) >= 0,
        "name": n.ssid,
        "sub": (n.inUse ? "Connected" : n.signal + "%") + (saved.indexOf(n.ssid) >= 0 ? " · Saved" : (n.isSecure ? " · Secured" : "")),
        "icon": "wifi",
        "tint": "accentBlue"
    })));
}

// Whether choosing a network tile asks for its password first
function needsPassword(item) {
    return !!item.network && item.secure && !item.saved && !item.inUse;
}

// The line under the network name. `failed` is the network the last connect failed on.
function wifiStatus(enabled, connected, connecting, scanning, signal, count, failed) {
    if (!enabled) return "Turn Wi-Fi on from the ring";
    if (connecting !== "") return "Connecting to " + connecting + "…";
    if (failed) return "Could not connect to " + failed;
    if (scanning && count === 0) return "Scanning…";
    let found = count + (count === 1 ? " network" : " networks");
    return connected ? "Signal " + signal + "% · " + found : found;
}

// How the battery gauge is coloured: "charging", "critical" (10% or less), "low" (20% or
// less) or "normal"
function batteryTone(fraction, charging) {
    if (charging) return "charging";
    if (fraction <= 0.10) return "critical";
    if (fraction <= 0.20) return "low";
    return "normal";
}

function formatDuration(seconds) {
    if (!seconds || isNaN(seconds) || seconds <= 0) return "";
    let hrs = Math.floor(seconds / 3600);
    let mins = Math.floor((seconds % 3600) / 60);
    return hrs > 0 ? hrs + "h " + mins + "m" : mins + "m";
}

// The line under the battery level
function batteryStatus(present, charging, full, timeToFull, timeToEmpty) {
    if (!present) return "No battery";
    if (full) return "Fully charged";
    if (charging) {
        let toFull = formatDuration(timeToFull);
        return toFull !== "" ? "Charging · " + toFull + " until full" : "Charging";
    }
    let left = formatDuration(timeToEmpty);
    return left !== "" ? left + " remaining" : "On battery";
}

// The Bluetooth page's ring: the adapter off or on
var BLUETOOTH_RING = ["Bluetooth Off", "Bluetooth On"];

function percent(fraction) {
    return Math.round(fraction * 100) + "%";
}

// The Bluetooth page's arc: Settings, then the paired devices as BluetoothService lists
// them (connected first). Choosing a device connects or disconnects it.
function bluetoothItems(devices, enabled) {
    let list = [{ "kind": "action", "id": "bluetoothSettings", "name": "Settings", "icon": "settings", "tint": "accentBlue" }];
    if (!enabled) return list;
    return list.concat(devices.map(d => ({
        "kind": "action",
        "id": "bt:" + d.mac,
        "device": d.mac,
        "inUse": !!d.isConnected,
        "name": d.name,
        "sub": (d.isConnected ? "Connected" : "Not connected") + (d.battery >= 0 ? " · " + percent(d.battery) : ""),
        "icon": d.icon,
        "tint": "accentBlue"
    })));
}

// The line under the device name. `connecting` is the name of the device connecting.
function bluetoothStatus(available, enabled, connected, connecting, battery, count) {
    if (!available) return "No Bluetooth adapter found";
    if (!enabled) return "Turn Bluetooth on from the ring";
    if (connecting !== "") return "Connecting to " + connecting + "…";
    if (count === 0) return "No paired devices";
    let paired = count + " paired";
    if (connected && battery >= 0) return "Battery " + percent(battery) + " · " + paired;
    return paired;
}

// The hardware page's ring: which reading the middle and the gauge show, and what the
// programs on the arc are sorted by (memory for Memory, CPU otherwise)
var HARDWARE_RING = ["CPU", "Memory", "Temperature"];
var HARDWARE_PROGRAMS = 8;

// Programs that keep the desktop itself running. The dial does not offer to end them.
var PROTECTED_PROGRAMS = ["systemd", "kwin_wayland", "kwin_x11", "plasmashell", "quickshell", "qs", "Xwayland",
    "pipewire", "pipewire-pulse", "wireplumber", "dbus-daemon", "dbus-broker", "dbus-broker-lau", "sddm",
    "startplasma-way", "ksmserver", "kded6", "polkit-kde-auth", "kwalletd6", "NetworkManager", "python3"];

function canEnd(name) {
    return PROTECTED_PROGRAMS.indexOf(name) < 0;
}

function formatMemory(mb) {
    return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB";
}

// The hardware page's arc: System Monitor, then the busiest programs by `metric`'s order
function hardwareItems(programs, metric) {
    let byMemory = metric === 1;
    let sorted = programs.slice().sort((a, b) => byMemory ? b.memMb - a.memMb : b.cpu - a.cpu).slice(0, HARDWARE_PROGRAMS);
    return [{ "kind": "action", "id": "systemMonitor", "name": "System Monitor", "icon": "cpu", "tint": "accentBlue" }]
        .concat(sorted.map(p => ({
            "kind": "process",
            "id": "proc:" + p.name,
            "process": p.name,
            "name": p.name,
            "sub": byMemory ? formatMemory(p.memMb) : p.cpu + "% CPU",
            "icon": p.name,
            "fallback": "application-x-executable"
        })));
}

// How a reading is coloured: "critical", "high" or "normal". Temperature is in °C, the
// others in percent.
function hardwareTone(metric, value) {
    if (metric === 2) return value > 75 ? "critical" : (value > 60 ? "high" : "normal");
    return value >= 90 ? "critical" : (value >= 75 ? "high" : "normal");
}

// The big reading in the middle for `metric`, and the line under it with the other two
function hardwareTitle(metric, cpu, ram, temp) {
    if (metric === 1) return ram + "%";
    if (metric === 2) return temp > 0 ? temp + " °C" : "No sensor";
    return cpu + "%";
}

function hardwareStatus(metric, cpu, ram, usedGb, totalGb, temp) {
    let heat = temp > 0 ? temp + " °C" : "";
    let parts;
    if (metric === 1) parts = [usedGb + " of " + totalGb + " GB", "CPU " + cpu + "%"];
    else if (metric === 2) parts = ["CPU " + cpu + "%", "Memory " + ram + "%"];
    else parts = ["Memory " + ram + "%", heat];
    return parts.filter(p => p !== "").join(" · ");
}

// The microphone page's ring: muted or live
var MIC_RING = ["Muted", "Live"];
var SLIDER_BAND = 16;  // how far off the gauge (px) a press still takes the slider

// The microphone page's arc: Settings, then the inputs as MicrophoneService lists them.
// Choosing one makes it the default input.
function micItems(sources) {
    return [{ "kind": "action", "id": "audioSettings", "name": "Settings", "icon": "settings", "tint": "accentBlue" }]
        .concat(sources.map(s => ({
            "kind": "action",
            "id": "src:" + s.name,
            "source": s.name,
            "inUse": !!s.isDefault,
            "name": s.displayName,
            "sub": s.isDefault ? "In use" : "Input",
            "icon": "mic",
            "tint": "accentRed"
        })));
}

// The line under the input level
function micStatus(available, muted, device) {
    if (!available) return "No microphone found";
    return muted ? "Muted · " + device : device;
}

// --- Gauge slider ---
// A page whose gauge is a slider (the microphone's level) takes presses on the gauge's
// band. dx and dy are from the dial's centre; `radius` is the gauge's and `band` how far
// off it a press still counts, both in the same units.
function onGauge(dx, dy, radius, band, start, span) {
    if (Math.abs(Math.hypot(dx, dy) - radius) > band) return false;
    let level = gaugeAt(dx, dy, start, span, true);
    return level >= 0;
}

// The level (0 to 1) of the gauge at a point. The gauge runs from `start` degrees (level 0)
// back by `span` degrees (level 1), clockwise from three o'clock. Points beyond its ends
// give the nearer end, or -1 when `strict` and more than a few degrees out.
function gaugeAt(dx, dy, start, span, strict) {
    let a = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360;
    let end = start - span;
    let slack = strict ? 6 : 0;
    if (a >= end && a <= start) return (start - a) / span;
    // Past `start` the level is 0 up to the point opposite the gauge's middle, 1 after it
    let opposite = (start - span / 2 + 180) % 360;
    let pastStart = (a - start + 360) % 360;
    let toOpposite = (opposite - start + 360) % 360;
    if (pastStart <= toOpposite) return strict && pastStart > slack ? -1 : 0;
    return strict && (end - a + 360) % 360 > slack ? -1 : 1;
}
