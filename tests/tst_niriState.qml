import QtQuick
import QtTest
import "../services/niriState.js" as NiriState

TestCase {
    name: "NiriState"

    // A recording in tests/data/niri, as lines (test.sh allows file reads for this)
    function recording(name) {
        let xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("data/niri/" + name + ".jsonl"), false);
        xhr.send();
        return xhr.responseText.split("\n");
    }

    function replay(state, name) {
        let lines = recording(name);
        for (let i = 0; i < lines.length; i++) NiriState.applyLine(state, lines[i]);
        return state;
    }

    function started() {
        return replay(NiriState.emptyState(), "startup");
    }

    function test_startup() {
        let s = started();
        compare(Object.keys(s.windows).length, 3);
        compare(Object.keys(s.workspaces).length, 4);
        compare(NiriState.focusedWindow(s).id, 11);
        compare(NiriState.focusedOutput(s), "DP-1");
        compare(s.keyboardLayouts, ["English (US)", "Finnish"]);
        compare(s.keyboardLayoutIndex, 0);
        compare(s.overviewOpen, false);
        compare(s.configLoads, 1);
        compare(s.configFailed, false);
    }

    function test_replyAndBadLinesChangeNothing() {
        let s = NiriState.emptyState();
        verify(!NiriState.applyLine(s, "{\"Ok\":\"Handled\"}"));
        verify(!NiriState.applyLine(s, "{\"Err\":\"error parsing request\"}"));
        verify(!NiriState.applyLine(s, "not json"));
        verify(!NiriState.applyLine(s, ""));
        verify(!NiriState.apply(s, null));
        verify(!NiriState.apply(s, [1]));
        verify(!NiriState.apply(s, { "A": {}, "B": {} }));
        compare(s, NiriState.emptyState());
    }

    function test_unknownEventsAreIgnored() {
        let s = started();
        verify(!NiriState.apply(s, { "SomethingNewerNiriSends": { "value": 1 } }));
        verify(!NiriState.apply(s, { "CastsChanged": { "casts": [] } }));
    }

    function test_workspaceListOrderAndCounts() {
        let list = NiriState.workspaceList(started());
        compare(list.map(w => w.id), [1, 2, 3, 4]);
        compare(list.map(w => w.output), ["DP-1", "DP-1", "HDMI-A-1", "HDMI-A-1"]);
        compare(list.map(w => w.windowCount), [2, 0, 1, 0]);
        compare(list[0].name, "web");
    }

    function test_windowListOrder() {
        let list = NiriState.windowList(started());
        compare(list.map(w => w.id), [11, 12, 13]);
    }

    function test_session() {
        let s = replay(started(), "session");
        // 14 opened focused, then focus went to 12, 12 got a new title, 14 closed
        verify(!(14 in s.windows));
        compare(s.windows[12].title, "~/code");
        compare(s.windows[12].layout.window_size, [2028, 1384]);
        compare(s.windows[11].is_focused, false);
        // The last focus change was to no window at all
        compare(NiriState.focusedWindow(s), null);
        // Workspace 4 took over HDMI-A-1 and focus
        compare(s.workspaces[4].is_active, true);
        compare(s.workspaces[3].is_active, false);
        compare(s.workspaces[1].is_active, true);
        compare(s.workspaces[1].is_focused, false);
        compare(NiriState.focusedOutput(s), "HDMI-A-1");
        compare(s.workspaces[1].active_window_id, 14);
        compare(s.windows[13].is_urgent, true);
        compare(s.workspaces[3].is_urgent, true);
        compare(s.overviewOpen, true);
        compare(s.keyboardLayoutIndex, 1);
        compare(s.configLoads, 2);
        compare(s.configFailed, true);
    }

    function test_openingAFocusedWindowUnfocusesTheOthers() {
        let s = started();
        NiriState.apply(s, { "WindowOpenedOrChanged": { "window": { "id": 20, "workspace_id": 1, "is_focused": true } } });
        compare(NiriState.focusedWindow(s).id, 20);
        compare(s.windows[11].is_focused, false);
    }

    function test_eventsForUnknownIds() {
        let s = started();
        verify(!NiriState.apply(s, { "WindowClosed": { "id": 99 } }));
        verify(!NiriState.apply(s, { "WindowUrgencyChanged": { "id": 99, "urgent": true } }));
        verify(!NiriState.apply(s, { "WorkspaceActivated": { "id": 99, "focused": true } }));
        verify(!NiriState.apply(s, { "WorkspaceActiveWindowChanged": { "workspace_id": 99, "active_window_id": 1 } }));
        verify(!NiriState.apply(s, { "WindowLayoutsChanged": { "changes": [[99, {}]] } }));
        compare(NiriState.focusedOutput(s), "DP-1");
    }

    function test_monitorUnplug() {
        let s = replay(started(), "unplug");
        let list = NiriState.workspaceList(s);
        compare(list.map(w => w.output), ["DP-1", "DP-1", "DP-1", "DP-1"]);
        compare(list.map(w => w.id), [1, 2, 3, 5]);
        // The window on HDMI-A-1's workspace keeps its workspace id
        compare(list[2].windowCount, 1);
    }

    function test_trackedWindows() {
        let list = NiriState.trackedWindows(started());
        compare(list.map(w => w.id), ["11", "12", "13"]);
        let firefox = list[0];
        compare(firefox.app, "org.mozilla.firefox");
        compare(firefox.active, true);
        compare(firefox.onCurrent, true);
        compare(firefox.screen, "DP-1");
        compare(firefox.desktops, ["1"]);
        compare(firefox.spansHeight, true);
        compare(firefox.minimized, false);
        let calc = list[2];
        compare(calc.floating, true);
        compare(calc.spansHeight, false);
        compare(calc.screen, "HDMI-A-1");
        compare([calc.x, calc.y, calc.width, calc.height], [1800, 700, 360, 620]);
    }

    function test_onCurrentFollowsTheActiveWorkspace() {
        let s = started();
        NiriState.apply(s, { "WorkspaceActivated": { "id": 2, "focused": true } });
        let list = NiriState.trackedWindows(s);
        compare(list.map(w => w.onCurrent), [false, false, true]);
    }

    function test_nextWorkspaceFor() {
        let s = started();
        compare(NiriState.nextWorkspaceFor(s, "11"), 2);
        compare(NiriState.nextWorkspaceFor(s, 13), 4);
        compare(NiriState.nextWorkspaceFor(s, 99), null);
        // A window on the last workspace of its output has nowhere to go
        NiriState.apply(s, { "WindowOpenedOrChanged": { "window": { "id": 20, "workspace_id": 4 } } });
        compare(NiriState.nextWorkspaceFor(s, 20), null);
    }

    function test_windowIdsOfApp() {
        let s = started();
        NiriState.apply(s, { "WindowOpenedOrChanged": { "window": { "id": 5, "app_id": "foot", "workspace_id": 2 } } });
        compare(NiriState.windowIdsOfApp(s, "foot"), [5, 12]);
        compare(NiriState.windowIdsOfApp(s, ""), []);
    }

    function test_desktopsOnHideTheTrailingEmptyWorkspace() {
        let s = started();
        let dp = NiriState.desktopsOn(s, "DP-1");
        compare(dp.length, 1);
        compare(dp[0], { "id": "1", "name": "web", "index": 0, "isCurrent": true, "urgent": false });
        compare(NiriState.desktopsOn(s, "HDMI-A-1").map(d => d.id), ["3"]);
        // No output given: the focused one
        compare(NiriState.desktopsOn(s, "").map(d => d.id), ["1"]);
        compare(NiriState.desktopsOn(s, "nowhere"), []);
    }

    function test_desktopsOnShowsTheEmptyWorkspaceWhenActive() {
        let s = started();
        NiriState.apply(s, { "WorkspaceActivated": { "id": 2, "focused": true } });
        let dp = NiriState.desktopsOn(s, "DP-1");
        compare(dp.map(d => d.id), ["1", "2"]);
        compare(dp.map(d => d.isCurrent), [false, true]);
        compare(dp[1].index, 1);
    }

    function test_desktopsOnAnEmptyOutput() {
        let s = NiriState.emptyState();
        NiriState.apply(s, { "WorkspacesChanged": { "workspaces": [{ "id": 7, "idx": 1, "output": "DP-2", "is_active": true }] } });
        compare(NiriState.desktopsOn(s, "DP-2").map(d => d.id), ["7"]);
    }

    function test_actionRequest() {
        compare(NiriState.actionRequest("FocusWindow", { "id": 3 }), "{\"Action\":{\"FocusWindow\":{\"id\":3}}}\n");
        compare(NiriState.actionRequest("FocusWorkspaceDown"), "{\"Action\":{\"FocusWorkspaceDown\":{}}}\n");
    }
}
