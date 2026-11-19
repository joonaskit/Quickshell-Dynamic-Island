.pragma library

// Window-to-app matching used by DockService.findToplevels. Kept free of
// Quickshell types so it can be tested with qmltestrunner (see tests/).

function normalize(s) {
    return (s || "").toLowerCase().replace(/\.desktop$/, "");
}

// Returns the windows in `windows` that belong to `app`.
// app:      { id, desktopFile, rawAppId, command, name }, all optional
// windows:  [{ appId, ownEntry, ... }], as built by DockService.getMergedWindows;
//           ownEntry is the id of the desktop entry the app-id names exactly, or 
// wmClass:  the desktop entry's StartupWMClass, or "" if it has none
//
// Entries declaring StartupWMClass are matched exactly, so that e.g. a
// Vivaldi PWA window is not mistaken for the Vivaldi browser itself. Other
// entries fall back to substring matching on id, command and name, except for a
// window whose app-id names another desktop entry exactly: it is that app's (#150).
function matchWindows(app, windows, wmClass) {
    let list = [];
    if (!windows || windows.length === 0) return list;

    let idLower = normalize(app.id);
    let deskLower = normalize(app.desktopFile);
    let rawLower = normalize(app.rawAppId);
    let cmdLower = (app.command || "").toLowerCase();
    let nameLower = (app.name || "").toLowerCase();
    let nameWord = nameLower.replace(/\s+/g, "");
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
        let own = normalize(w.ownEntry);
        if (!match && own.length > 0 && own !== idLower && own !== deskLower) continue;
        if (!match && idLower.length > 2 && (wApp.endsWith("." + idLower) || deskLower.endsWith("." + wApp) || idLower.indexOf(wApp) >= 0 || wApp.indexOf(idLower) >= 0)) {
            match = true;
        }
        if (!match && rawLower.length > 2 && (wApp.endsWith("." + rawLower) || rawLower.indexOf(wApp) >= 0 || wApp.indexOf(rawLower) >= 0)) {
            match = true;
        }
        if (!match && cmdLower.length > 2 && (wApp === cmdLower || wApp.indexOf(cmdLower) >= 0 || cmdLower.indexOf(wApp) >= 0)) {
            match = true;
        }
        // The name only as a whole part of the app-id: "Settings" matches org.gnome.Settings
        // but not io.github.joonaskit.NiriSettings
        if (!match && nameWord.length > 3 && wApp.split(/[.\-_]/).indexOf(nameWord) >= 0) {
            match = true;
        }

        if (match) {
            list.push(w);
        }
    }
    return list;
}
