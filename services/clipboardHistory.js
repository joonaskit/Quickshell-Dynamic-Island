.pragma library

// Clipboard history operations used by ClipboardService and the clipboard window.
// Entries look like { id, text, kind, sensitive, size, chars, lines, firstTime,
// time, count, app, appTitle, pinned }, newest first. Kept free of Quickshell
// types so it can be tested with qmltestrunner (see tests/).

// Records a copy and returns the new history. A copy of text already in the history
// moves that entry to the front and raises its count. `record` is a text record from
// clipboard_tracker.py, `source` is { app, title } of the focused window (may be empty).
function addCopy(history, record, source, id) {
    let list = history.slice();
    let idx = list.findIndex(e => e.text === record.text);
    let entry;
    if (idx !== -1) {
        entry = Object.assign({}, list[idx], {
            "count": list[idx].count + 1,
            "time": record.time,
            "app": source.app,
            "appTitle": source.title
        });
        list.splice(idx, 1);
    } else {
        entry = {
            "id": id,
            "text": record.text,
            "kind": record.kind,
            "sensitive": record.sensitive,
            "size": record.size,
            "chars": record.chars,
            "lines": record.lines,
            "firstTime": record.time,
            "time": record.time,
            "count": 1,
            "app": source.app,
            "appTitle": source.title,
            "pinned": false
        };
    }
    list.unshift(entry);
    return list;
}

// Drops the oldest unpinned entries beyond `max`
function trim(history, max) {
    let over = history.length - max;
    if (over <= 0) return history;
    let list = history.slice();
    for (let i = list.length - 1; i >= 0 && over > 0; i--) {
        if (!list[i].pinned) {
            list.splice(i, 1);
            over--;
        }
    }
    return list;
}

// Drops unpinned credential-like entries copied `seconds` or more before `now` (ms).
// Returns the same array when nothing expired.
function expireSensitive(history, now, seconds) {
    if (seconds <= 0) return history;
    let list = history.filter(e => !(e.sensitive && !e.pinned && now - e.time >= seconds * 1000));
    return list.length === history.length ? history : list;
}

function isIgnoredApp(appId, ignored) {
    return appId !== "" && ignored.indexOf(appId.toLowerCase()) !== -1;
}

// Entries for the clipboard window: pinned first, then by recency. `filter` is
// "all", "text", "url" or "pinned". Credential-like entries never match a search
// query, so typing cannot be used to probe their content.
function view(history, query, filter) {
    let q = query.trim().toLowerCase();
    let list = history.filter(e => {
        if (filter === "pinned" && !e.pinned) return false;
        if ((filter === "text" || filter === "url") && e.kind !== filter) return false;
        if (q === "") return true;
        if (e.sensitive) return false;
        return e.text.toLowerCase().indexOf(q) !== -1 || e.appTitle.toLowerCase().indexOf(q) !== -1;
    });
    return list.filter(e => e.pinned).concat(list.filter(e => !e.pinned));
}

// One-line preview of a text
function preview(text, maxLen) {
    let s = text.replace(/\s+/g, " ").trim();
    return s.length > maxLen ? s.slice(0, maxLen - 1) + "…" : s;
}

function formatSize(bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

// "just now", "5 min ago", "2 h ago" or a date
function formatAge(time, now) {
    let s = Math.max(0, Math.floor((now - time) / 1000));
    if (s < 10) return "just now";
    if (s < 60) return s + " s ago";
    if (s < 3600) return Math.floor(s / 60) + " min ago";
    if (s < 86400) return Math.floor(s / 3600) + " h ago";
    return new Date(time).toLocaleDateString();
}
