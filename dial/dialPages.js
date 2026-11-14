.pragma library

// The arcs and readouts of the dial's later status pages: Night Light, Hue, notifications,
// clipboard, KDE Connect, drives and GameMode. The first pages (power, Wi-Fi, Bluetooth,
// hardware, microphone) are in dialLogic.js. Tested by tests/tst_dialPages.qml.
//
// Tiles are of kind "action" unless said otherwise. Besides the fields dialLogic.js
// describes, a tile here may have:
//   lit      drawn filled, as a toggle that is on
//   start    the arc starts on it when the page opens
//   stay     choosing it leaves the dial open
//   card     choosing it opens that icon's sheet (DialSheet), for what a page cannot hold
//   section  choosing it opens the shell's settings at that section of the Top bar tab

function settingsTile(section) {
    return { "kind": "action", "id": "iconSettings", "name": "Settings", "icon": "settings", "tint": "accentBlue", "section": section };
}

// How far one wheel step moves a page's slider (the gauge), as a part of its length
var SLIDER_STEP = { "mic": 0.05, "nightLight": 100 / 5500, "hue": 0.05 };

function plural(count, one, many) {
    return count + " " + (count === 1 ? one : many);
}

// --- Night Light ---
var NIGHT_RING = ["Night Light Off", "Night Light On"];

// Where `value` sits between min and max, 0 to 1
function levelOf(value, min, max) {
    return max > min ? Math.max(0, Math.min(1, (value - min) / (max - min))) : 0;
}

// The night temperature at a slider level, to the nearest 100 K
function kelvinAt(level, min, max) {
    return Math.round((min + Math.max(0, Math.min(1, level)) * (max - min)) / 100) * 100;
}

// Settings, then the three schedules (`mode` is NightLightService.shownMode), then Edit
// Hours while the custom hours are in use
function nightLightItems(available, mode, start, end) {
    let list = [settingsTile("optionalIcons")];
    if (!available) return list;
    let modes = [
        { "id": "DarkLight", "name": "Sunset", "sub": "To sunrise", "icon": "moon" },
        { "id": "Constant", "name": "Always On", "sub": "All day", "icon": "brightness-high" },
        { "id": "Custom", "name": "Custom", "sub": start + " – " + end, "icon": "clock" }
    ];
    modes.forEach(m => list.push({
        "kind": "action", "id": "night:" + m.id, "nightMode": m.id, "name": m.name, "sub": m.sub, "icon": m.icon,
        "tint": "accentOrangeStrong", "lit": mode === m.id, "start": mode === m.id, "stay": true
    }));
    if (mode === "Custom") list.push({ "kind": "action", "id": "nightHours", "name": "Edit Hours", "icon": "clock", "tint": "accentBlue", "card": "nightLight" });
    return list;
}

// `s` holds NightLightService's available, switchedOn, custom, inWindow, scheduleStart,
// scheduleEnd, running, currentTemperature and daylight
function nightLightStatus(s) {
    if (!s.available) return "Not available in this session";
    if (!s.switchedOn) return "Off";
    if (s.custom) return s.inWindow ? "Tinting until " + s.scheduleEnd : "On, starts at " + s.scheduleStart;
    if (s.running) return "Tinting at " + s.currentTemperature + " K";
    return s.daylight ? "On, waiting for the evening" : "On";
}

// --- Hue ---
// The ring holds the lamps; the arc acts on the one chosen there
function hueRing(lights) {
    return lights.length > 0 ? lights.map(l => l.name) : ["Hue"];
}

function hueIndex(lights, light) {
    let i = light ? lights.findIndex(l => l.id === light.id) : -1;
    return i >= 0 ? i : 0;
}

// Bridge (the sheet, for pairing and forgetting), Favourite, the lamp's switch, and three
// whites for a lamp with colour temperature
function hueItems(light, favouriteId) {
    let list = [{ "kind": "action", "id": "hueBridge", "name": "Bridge", "icon": "settings", "tint": "accentBlue", "card": "hue" }];
    if (!light) return list;
    list.push({ "kind": "action", "id": "hueFavourite", "name": "Favourite", "sub": "Shown first", "icon": "pin", "tint": "accentOrangeStrong",
        "lit": light.id === favouriteId, "stay": true });
    list.push({ "kind": "action", "id": "huePower", "name": light.on ? "On" : "Off", "sub": light.name, "icon": "bulb", "tint": "accentOrangeStrong",
        "lit": !!light.on, "start": true, "stay": true });
    if (light.hasColorTemp) {
        let whites = [
            { "name": "Warm", "mirek": light.mirekMax },
            { "name": "Neutral", "mirek": Math.round((light.mirekMin + light.mirekMax) / 2) },
            { "name": "Cool", "mirek": light.mirekMin }
        ];
        whites.forEach(w => list.push({
            "kind": "action", "id": "hueWhite:" + w.name, "mirek": w.mirek, "name": w.name, "sub": Math.round(1000000 / w.mirek / 100) * 100 + " K",
            "icon": "brightness-low", "tint": "accentOrangeStrong", "lit": !!light.on && Math.abs(light.mirek - w.mirek) <= 10, "stay": true
        }));
    }
    return list;
}

function hueTitle(light) {
    if (!light) return "Philips Hue";
    if (!light.on) return "Off";
    return light.hasBrightness ? Math.round(light.brightness) + "%" : "On";
}

function hueStatus(error, connected, light) {
    if (error !== "") return error;
    if (!connected) return "Connecting…";
    if (!light) return "No lights found";
    return light.name;
}

// --- Notifications ---
// The ring filters by app: All, then one pill per app (NotificationService.groups)
function notificationRing(groups) {
    let total = groups.reduce((n, g) => n + g.items.length, 0);
    return ["All " + total].concat(groups.map(g => g.appName + " " + g.items.length));
}

function notificationIndex(groups, app) {
    return groups.findIndex(g => g.appName === app) + 1;
}

// Clear All (when there is something to clear) and Do Not Disturb, then the notifications
// of `app` ("" for all), newest first as the service keeps them. A notification is a tile
// of kind "notification"; choosing it opens its menu.
function notificationItems(notifications, app, dnd) {
    let shown = notifications.filter(n => app === "" || (n.appName || "System") === app);
    let list = [];
    if (shown.length > 0) list.push({ "kind": "action", "id": "clearNotifications", "name": app === "" ? "Clear All" : "Clear These",
        "icon": "trash", "tint": "accentRed", "confirm": shown.length > 1, "stay": true });
    list.push({ "kind": "action", "id": "dnd", "name": "Do Not Disturb", "icon": "bell-off", "tint": "accentPurple", "lit": dnd,
        "start": shown.length === 0, "stay": true });
    return list.concat(shown.map((n, i) => ({
        "kind": "notification",
        "id": "notif:" + n.id,
        "notification": n.id,
        "app": n.appName || "System",
        "name": n.summary || n.appName || "Notification",
        "sub": (n.appName || "System") + (n.time ? " · " + n.time : ""),
        "body": n.body || "",
        "icon": n.appIcon || "",
        "fallback": "preferences-desktop-notification",
        "start": i === 0
    })));
}

function notificationTitle(count) {
    return count === 0 ? "No notifications" : plural(count, "notification", "notifications");
}

// The line under the count: the body of the notification the arc is on, else the state
function notificationStatus(focused, dnd) {
    if (focused && focused.kind === "notification") {
        let body = focused.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
        return body !== "" ? body : focused.name;
    }
    return dnd ? "Do Not Disturb is on" : "Banners are on";
}

// --- Clipboard ---
// The ring filters the history, by clipboardHistory.js's filter names
var CLIPBOARD_RING = ["All", "Pinned", "Text", "Links", "Images", "Files"];
var CLIPBOARD_FILTERS = ["all", "pinned", "text", "url", "image", "files"];
var CLIPBOARD_ICONS = { "text": "clipboard", "url": "window", "image": "desktop", "files": "folder" };
var CLIPBOARD_ENTRIES = 24;

// History (the clipboard window), Incognito and Clear, then the entries. `entries` are
// [{ id, kind, pinned, sensitive, label, age }], already filtered and ordered. Choosing
// an entry copies it again.
function clipboardItems(entries, incognito, hasHistory) {
    let list = [
        { "kind": "action", "id": "clipboardWindow", "name": "History", "sub": "Open window", "icon": "clipboard", "tint": "accentBlue" },
        { "kind": "action", "id": "incognito", "name": "Incognito", "sub": incognito ? "Not saving" : "", "icon": "lock", "tint": "accentPurple",
            "lit": incognito, "stay": true, "start": entries.length === 0 }
    ];
    if (hasHistory) list.push({ "kind": "action", "id": "clearClipboard", "name": "Clear", "sub": "Keeps pinned", "icon": "trash", "tint": "accentRed",
        "confirm": true, "stay": true });
    return list.concat(entries.slice(0, CLIPBOARD_ENTRIES).map((e, i) => ({
        "kind": "action",
        "id": "clip:" + e.id,
        "clip": e.id,
        "pinned": !!e.pinned,
        "name": e.sensitive ? "Hidden" : e.label,
        "sub": (e.pinned ? "Pinned · " : "") + e.age,
        "icon": e.sensitive ? "lock" : (CLIPBOARD_ICONS[e.kind] || "clipboard"),
        "tint": e.pinned ? "accentOrangeStrong" : "accentBlue",
        "start": i === 0
    })));
}

// What the clipboard holds now. `c` holds ClipboardService's hiddenReason, hiddenText,
// currentFiles, currentBinaryType, currentText and currentSensitive.
function clipboardStatus(c, preview) {
    if (c.hiddenReason !== "") return c.hiddenText;
    if (c.currentFiles.length > 0) return plural(c.currentFiles.length, "file", "files") + " on clipboard";
    if (c.currentBinaryType !== "") return c.currentBinaryType.indexOf("image/") === 0 ? "Image on clipboard" : "Non-text content on clipboard";
    if (c.currentText !== "") return c.currentSensitive ? "Hidden: looks like a credential" : preview;
    return "Clipboard is empty";
}

// --- KDE Connect ---
function kdeRing(devices) {
    return devices.length > 0 ? devices.map(d => d.name) : ["KDE Connect"];
}

// Settings, then what the device offers while it is reachable. Send Text opens the sheet,
// which has the field for it.
function kdeItems(device) {
    let list = [settingsTile("optionalIcons")];
    if (!device || !device.reachable) return list;
    let add = (id, name, icon, extra) => list.push(Object.assign({ "kind": "action", "id": id, "name": name, "icon": icon, "tint": "accentGreenStrong" }, extra || {}));
    if (device.canPing) add("kdePing", "Ping", "bell", { "stay": true, "start": true });
    if (device.canRing) add("kdeRing", "Find Phone", "phone", { "stay": true });
    if (device.canClipboard) add("kdeClipboard", "Send Clipboard", "clipboard", { "stay": true });
    if (device.canShare) {
        add("kdeFile", "Send File", "folder");
        add("kdeText", "Send Text", "copy", { "card": "kdeConnect" });
    }
    return list;
}

function kdeStatus(daemonAvailable, device, notice) {
    if (!daemonAvailable) return "KDE Connect is not running";
    if (!device) return "No paired devices";
    if (notice !== "") return notice;
    if (!device.reachable) return "Not connected. Open KDE Connect on the phone";
    if (device.hasBattery) return "Battery " + device.charge + "%" + (device.charging ? " · Charging" : "");
    return "Connected";
}

// --- Drives ---
// Rescan, then every partition of every detachable drive (a drive without partitions
// counts as one). Choosing a mounted one opens it, another mounts it; the tile's menu
// unmounts and ejects. `busy` is the path DeviceService is working on.
function driveItems(devices, busy) {
    let list = [{ "kind": "action", "id": "rescanDrives", "name": "Rescan", "icon": "refresh", "tint": "accentBlue", "stay": true }];
    devices.forEach(dev => {
        let parts = dev.partitions && dev.partitions.length > 0 ? dev.partitions : [dev];
        parts.forEach(p => {
            let working = busy !== "" && (busy === p.path || busy === dev.path);
            list.push({
                "kind": "action",
                "id": "drive:" + p.path,
                "drive": p.path,
                "parent": dev.path,
                "mounted": !!p.isMounted,
                "mountpoint": p.mountpoint || "",
                "name": p.title || p.label || p.name || dev.title || dev.name,
                "sub": working ? "Working…" : (p.isMounted ? (p.usePercent !== undefined && p.usePercent !== null ? p.usePercent + "% used" : "Mounted")
                    : (p.sizeFormatted ? p.sizeFormatted + " · " : "") + "Not mounted"),
                "icon": "usb",
                "tint": "accentGreenStrong",
                "lit": !!p.isMounted,
                "start": list.length === 1,
                "stay": !p.isMounted
            });
        });
    });
    return list;
}

function driveTitle(count) {
    return count === 0 ? "No drives" : plural(count, "drive", "drives");
}

function driveStatus(count, mounted, busy, message) {
    if (busy !== "") return message !== "" ? message : "Working…";
    if (count === 0) return "Connect a USB drive or external disk";
    return mounted > 0 ? mounted + " mounted" : "None mounted";
}

// --- GameMode ---
// The ring forces GameMode on, or leaves it to the games that ask for it
var GAME_RING = ["Automatic", "Forced On"];

// Settings, then the games GameMode is on for (they do nothing when chosen)
function gameItems(games) {
    return [settingsTile("optionalIcons")].concat(games.map((g, i) => ({
        "kind": "action", "id": "game:" + g.pid, "name": g.name, "sub": "Running", "icon": "gamepad", "tint": "accentGreenStrong",
        "lit": true, "start": i === 0, "stay": true
    })));
}

function gameTitle(available, active) {
    if (!available) return "GameMode";
    return active ? "Active" : "Idle";
}

function gameStatus(available, games, forced) {
    if (!available) return "Not installed (sudo dnf install gamemode)";
    if (games > 0) return "For " + plural(games, "game", "games");
    return forced ? "Forced on" : "Starts with a game that asks for it";
}
