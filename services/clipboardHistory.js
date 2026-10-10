// Clipboard history operations used by ClipboardService and the clipboard window.
// Entries look like { id, type, kind, text, sensitive, size, chars, lines, firstTime,
// time, count, app, appTitle, pinned }, newest first. `type` is "text", "image" or
// "files". Text entries use `text` and `kind` ("text" or "url"); image entries have
// `mime`, `path` and `hash`; file entries have `files` and `dir`. For images and files
// `kind` is the type, `text` is empty. Kept free of Quickshell types so it can be tested
// with qmltestrunner (see tests/).

// What makes two records the same copy
function recordKey(record) {
    switch (record.type) {
    case "image": return "image:" + record.hash;
    case "files": return "files:" + record.files.join("\n");
    }
    return "text:" + record.text;
}

function entryKey(entry) {
    return recordKey({ "type": entry.type || "text", "text": entry.text, "hash": entry.hash, "files": entry.files });
}

function dirname(path) {
    let i = path.lastIndexOf("/");
    return i <= 0 ? "/" : path.slice(0, i);
}

// The folder the files were copied from: their shared parent, or the closest folder above all of them
function commonDir(files) {
    if (files.length === 0) return "";
    let common = dirname(files[0]).split("/");
    for (let f of files.slice(1)) {
        let parts = dirname(f).split("/");
        let n = 0;
        while (n < common.length && n < parts.length && common[n] === parts[n]) n++;
        common = common.slice(0, n);
    }
    return common.join("/") || "/";
}

// Records a copy and returns the new history. A repeat of a copy already in the history
// moves that entry to the front and raises its count. `record` is a record from
// clipboard_tracker.py, `source` is { app, title } of the focused window (may be empty).
function addCopy(history, record, source, id) {
    let type = record.type || "text";
    let key = recordKey(Object.assign({ "type": type }, record));
    let list = history.slice();
    let idx = list.findIndex(e => entryKey(e) === key);
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
            "type": type,
            "kind": type === "text" ? record.kind : type,
            "text": type === "text" ? record.text : "",
            "sensitive": type === "text" ? record.sensitive : false,
            "size": record.size || 0,
            "chars": record.chars || 0,
            "lines": record.lines || 0,
            "firstTime": record.time,
            "time": record.time,
            "count": 1,
            "app": source.app,
            "appTitle": source.title,
            "pinned": false
        };
        if (type === "image") {
            entry.mime = record.mime;
            entry.path = record.path;
            entry.hash = record.hash;
        } else if (type === "files") {
            entry.files = record.files;
            entry.dir = commonDir(record.files);
        }
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
// "all", "text", "url", "image", "files" or "pinned". Credential-like entries never match a search
// query, so typing cannot be used to probe their content.
function view(history, query, filter) {
    let q = query.trim().toLowerCase();
    let list = history.filter(e => {
        if (filter === "pinned" && !e.pinned) return false;
        if (filter !== "all" && filter !== "pinned" && e.kind !== filter) return false;
        if (q === "") return true;
        if (e.sensitive) return false;
        return searchable(e).toLowerCase().indexOf(q) !== -1 || e.appTitle.toLowerCase().indexOf(q) !== -1;
    });
    return list.filter(e => e.pinned).concat(list.filter(e => !e.pinned));
}

// The text a search matches: the copied text, or the paths of copied files
function searchable(entry) {
    return entry.type === "files" ? entry.files.join(" ") : entry.text;
}

function fileName(path) {
    return path.slice(path.lastIndexOf("/") + 1);
}

// Short description of an entry for lists: the text, "Image", or the file name(s)
function label(entry, maxLen) {
    if (entry.type === "image") return "Image";
    if (entry.type === "files") {
        let first = fileName(entry.files[0]);
        return entry.files.length === 1 ? first : first + " and " + (entry.files.length - 1) + " more";
    }
    return preview(entry.text, maxLen);
}

// An image file to preview: the copied image itself, or the first image among copied files
function thumbPath(entry) {
    if (entry.type === "image") return entry.path;
    if (entry.type === "files") {
        for (let f of entry.files) {
            if (/\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(f)) return f;
        }
    }
    return "";
}

// A folder path for display, with the home folder shortened to ~
function displayDir(dir, home) {
    if (home && home !== "/" && (dir === home || dir.indexOf(home + "/") === 0)) return "~" + dir.slice(home.length);
    return dir;
}

// file:// URL for a local path
function fileUrl(path) {
    return "file://" + encodeURI(path).replace(/[#?]/g, c => encodeURIComponent(c));
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
