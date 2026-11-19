.pragma library

// niri's windows and workspaces, kept current from its event stream (`niri msg
// event-stream`, or "EventStream" on $NIRI_SOCKET). Each line of the stream is one
// event, an object with a single key. `apply` folds an event into the state and has no
// I/O, so recorded event logs can be replayed into it (tests/tst_niriState.qml).
// NiriService owns the socket. Modelled on NiriState in niri-settings' ipc.py.

function emptyState() {
    return {
        "windows": {},          // id -> window, as niri sends it
        "workspaces": {},       // id -> workspace, as niri sends it
        "overviewOpen": false,
        "keyboardLayouts": [],
        "keyboardLayoutIndex": 0,
        "configLoads": 0,       // config loads seen, the first being niri's own at start
        "configFailed": false   // whether the last one failed
    };
}

// Folds one event into the state. Returns true if the state changed. Events this does
// not know, such as ones a newer niri adds, are ignored.
function apply(state, event) {
    if (!event || typeof event !== "object" || Array.isArray(event)) return false;
    let keys = Object.keys(event);
    if (keys.length !== 1) return false;
    let kind = keys[0];
    let data = event[kind] || {};

    switch (kind) {
    case "WindowsChanged": {
        state.windows = {};
        let list = data.windows || [];
        for (let i = 0; i < list.length; i++) state.windows[list[i].id] = list[i];
        return true;
    }
    case "WindowOpenedOrChanged": {
        let w = data.window;
        if (!w) return false;
        if (w.is_focused) {
            for (let id in state.windows) state.windows[id].is_focused = false;
        }
        state.windows[w.id] = w;
        return true;
    }
    case "WindowClosed":
        if (!(data.id in state.windows)) return false;
        delete state.windows[data.id];
        return true;
    case "WindowFocusChanged":
        // id is null when no window has focus
        for (let id in state.windows) state.windows[id].is_focused = state.windows[id].id === data.id;
        return true;
    case "WindowUrgencyChanged":
        if (!(data.id in state.windows)) return false;
        state.windows[data.id].is_urgent = !!data.urgent;
        return true;
    case "WindowLayoutsChanged": {
        let changes = data.changes || [];
        let changed = false;
        for (let i = 0; i < changes.length; i++) {
            let w = state.windows[changes[i][0]];
            if (!w) continue;
            w.layout = changes[i][1];
            changed = true;
        }
        return changed;
    }
    case "WorkspacesChanged": {
        state.workspaces = {};
        let list = data.workspaces || [];
        for (let i = 0; i < list.length; i++) state.workspaces[list[i].id] = list[i];
        return true;
    }
    case "WorkspaceActivated": {
        let target = state.workspaces[data.id];
        if (!target) return false;
        for (let id in state.workspaces) {
            let ws = state.workspaces[id];
            if (ws.output === target.output) ws.is_active = ws.id === data.id;
            if (data.focused) ws.is_focused = ws.id === data.id;
        }
        return true;
    }
    case "WorkspaceActiveWindowChanged": {
        let ws = state.workspaces[data.workspace_id];
        if (!ws) return false;
        ws.active_window_id = data.active_window_id;
        return true;
    }
    case "WorkspaceUrgencyChanged": {
        let ws = state.workspaces[data.id];
        if (!ws) return false;
        ws.is_urgent = !!data.urgent;
        return true;
    }
    case "OverviewOpenedOrClosed":
        state.overviewOpen = !!data.is_open;
        return true;
    case "KeyboardLayoutsChanged": {
        let layouts = data.keyboard_layouts || {};
        state.keyboardLayouts = layouts.names || [];
        state.keyboardLayoutIndex = layouts.current_idx || 0;
        return true;
    }
    case "KeyboardLayoutSwitched":
        state.keyboardLayoutIndex = data.idx || 0;
        return true;
    case "ConfigLoaded":
        state.configLoads++;
        state.configFailed = !!data.failed;
        return true;
    }
    return false;
}

// Folds one line of the stream in. The reply to the "EventStream" request ({"Ok": ...})
// and lines that are not JSON change nothing.
function applyLine(state, line) {
    let text = String(line || "").trim();
    if (text === "") return false;
    let event;
    try {
        event = JSON.parse(text);
    } catch (e) {
        return false;
    }
    if (event && (event.Ok !== undefined || event.Err !== undefined)) return false;
    return apply(state, event);
}

// Workspaces sorted by output, then by their index on it, each with `windowCount`
function workspaceList(state) {
    let counts = {};
    for (let id in state.windows) {
        let ws = state.windows[id].workspace_id;
        if (ws !== null && ws !== undefined) counts[ws] = (counts[ws] || 0) + 1;
    }
    let list = [];
    for (let id in state.workspaces) {
        let ws = Object.assign({}, state.workspaces[id]);
        ws.windowCount = counts[ws.id] || 0;
        list.push(ws);
    }
    list.sort(function(a, b) {
        let byOutput = String(a.output || "").localeCompare(String(b.output || ""));
        return byOutput !== 0 ? byOutput : a.idx - b.idx;
    });
    return list;
}

// Windows ordered as they sit: by workspace, then column and place in the column.
// Floating windows come after the tiled ones of their workspace.
function windowList(state) {
    let list = [];
    for (let id in state.windows) list.push(state.windows[id]);
    function pos(w) {
        let p = (w.layout || {}).pos_in_scrolling_layout;
        return p && !w.is_floating ? p : [1e9, 1e9];
    }
    list.sort(function(a, b) {
        let wa = a.workspace_id === null || a.workspace_id === undefined ? 1e9 : a.workspace_id;
        let wb = b.workspace_id === null || b.workspace_id === undefined ? 1e9 : b.workspace_id;
        if (wa !== wb) return wa - wb;
        let pa = pos(a), pb = pos(b);
        if (pa[0] !== pb[0]) return pa[0] - pb[0];
        if (pa[1] !== pb[1]) return pa[1] - pb[1];
        return a.id - b.id;
    });
    return list;
}

// Windows in the shape WindowService.windowList has under KWin, so the dock, launcher
// and island treat niri's windows as they do KWin's. Tiled windows span the working
// area's height (`spansHeight`); floating ones have a position on their output.
function trackedWindows(state) {
    let list = windowList(state);
    let out = [];
    for (let i = 0; i < list.length; i++) {
        let w = list[i];
        let ws = state.workspaces[w.workspace_id] || null;
        let layout = w.layout || {};
        let size = layout.window_size || [0, 0];
        let pos = w.is_floating ? layout.tile_pos_in_workspace_view : null;
        out.push({
            "id": String(w.id),
            "app": w.app_id || "",
            "title": w.title || "",
            "active": !!w.is_focused,
            "minimized": false,
            "onCurrent": !!(ws && ws.is_active),
            "screen": ws ? (ws.output || "") : "",
            "desktops": w.workspace_id === null || w.workspace_id === undefined ? [] : [String(w.workspace_id)],
            "floating": !!w.is_floating,
            "spansHeight": !w.is_floating && !!ws,
            "urgent": !!w.is_urgent,
            "x": pos ? pos[0] : 0,
            "y": pos ? pos[1] : 0,
            "width": size[0],
            "height": size[1],
            "pid": w.pid || 0
        });
    }
    return out;
}

// The window by its id (a number or the string trackedWindows gives), or null
function windowById(state, id) {
    return state.windows[Number(id)] || null;
}

// The id of the workspace a window moves to for "next desktop": the one below its own on
// the same output (niri always keeps an empty one last), or null when there is none
function nextWorkspaceFor(state, windowId) {
    let w = windowById(state, windowId);
    if (!w) return null;
    let ws = state.workspaces[w.workspace_id];
    if (!ws) return null;
    for (let id in state.workspaces) {
        let other = state.workspaces[id];
        if (other.output === ws.output && other.idx === ws.idx + 1) return other.id;
    }
    return null;
}

// Ids of the windows of an app, for quitting it
function windowIdsOfApp(state, appId) {
    let ids = [];
    for (let id in state.windows) {
        if (appId && state.windows[id].app_id === appId) ids.push(state.windows[id].id);
    }
    return ids.sort(function(a, b) { return a - b; });
}

// One output's workspaces in the shape WindowService.virtualDesktops has under KWin
// ({ id, name, index, isCurrent }, plus urgent). niri keeps an empty workspace last on
// each output; it is left out unless it is the active one. An empty output name means
// the focused workspace's output.
function desktopsOn(state, output) {
    let name = output || focusedOutput(state);
    let all = workspaceList(state).filter(function(ws) { return ws.output === name; });
    let out = [];
    for (let i = 0; i < all.length; i++) {
        let ws = all[i];
        let trailingEmpty = i === all.length - 1 && ws.windowCount === 0 && all.length > 1;
        if (trailingEmpty && !ws.is_active) continue;
        out.push({
            "id": String(ws.id),
            "name": ws.name || "",
            "index": ws.idx - 1,
            "isCurrent": !!ws.is_active,
            "urgent": !!ws.is_urgent
        });
    }
    return out;
}

function focusedWindow(state) {
    for (let id in state.windows) {
        if (state.windows[id].is_focused) return state.windows[id];
    }
    return null;
}

// The output of the focused workspace, or "" when none is known
function focusedOutput(state) {
    for (let id in state.workspaces) {
        if (state.workspaces[id].is_focused) return state.workspaces[id].output || "";
    }
    return "";
}

// The JSON line that asks niri to run an action: name is the action as niri's IPC names
// it ("FocusWindow"), fields its arguments ({ "id": 3 })
function actionRequest(name, fields) {
    let action = {};
    action[name] = fields || {};
    return JSON.stringify({ "Action": action }) + "\n";
}
