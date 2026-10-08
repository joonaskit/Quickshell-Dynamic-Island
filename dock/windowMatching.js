.pragma library

// Window-to-app matching used by DockService.findToplevels. Kept free of
// Quickshell types so it can be tested with qmltestrunner (see tests/).

function normalize(s) {
    return (s || "").toLowerCase().replace(/\.desktop$/, "");
}

// Returns the windows in `windows` that belong to `app`.
// app:      { id, desktopFile, rawAppId, command, name }, all optional
// windows:  [{ appId, ... }], as built by DockService.getMergedWindows
// wmClass:  the desktop entry's StartupWMClass, or "" if it has none
//
// Entries declaring StartupWMClass are matched exactly, so that e.g. a
// Vivaldi PWA window is not mistaken for the Vivaldi browser itself. Other
// entries fall back to substring matching on id, command and name.
function matchWindows(app, windows, wmClass) {
    let list = [];
    if (!windows || windows.length === 0) return list;

    let idLower = normalize(app.id);
    let deskLower = normalize(app.desktopFile);
    let rawLower = normalize(app.rawAppId);
    let cmdLower = (app.command || "").toLowerCase();
    let nameLower = (app.name || "").toLowerCase();
    let wmClassLower = (wmClass || "").toLowerCase();
    let strict = wmClassLower.length > 0;

    for (let i = 0; i < windows.length; i++) {
        let w = windows[i];
        if (!w || !w.appId) continue;
        let wApp = normalize(w.appId);

        let match = (wApp === idLower || wApp === deskLower || (rawLower.length > 0 && wApp === rawLower) || (strict && wApp === wmClassLower));
        if (strict) {
            if (match) list.push(w);
            continue;
        }
        if (!match && idLower.length > 2 && (wApp.endsWith("." + idLower) || deskLower.endsWith("." + wApp) || idLower.indexOf(wApp) >= 0 || wApp.indexOf(idLower) >= 0)) {
            match = true;
        }
        if (!match && rawLower.length > 2 && (wApp.endsWith("." + rawLower) || rawLower.indexOf(wApp) >= 0 || wApp.indexOf(rawLower) >= 0)) {
            match = true;
        }
        if (!match && cmdLower.length > 2 && (wApp === cmdLower || wApp.indexOf(cmdLower) >= 0 || cmdLower.indexOf(wApp) >= 0)) {
            match = true;
        }
        if (!match && nameLower.length > 3 && wApp.indexOf(nameLower) >= 0) {
            match = true;
        }

        if (match) {
            list.push(w);
        }
    }
    return list;
}
