import QtQuick
import QtTest
import "../services/refreshRate.js" as RefreshRate

TestCase {
    name: "RefreshRate"

    function mode(id, w, h, hz) {
        return { "id": id, "refreshRate": hz, "size": { "width": w, "height": h } };
    }

    function panel(currentModeId, extra) {
        let o = {
            "name": "eDP-1", "type": 7, "enabled": true, "connected": true, "currentModeId": currentModeId,
            "modes": [mode("1", 2880, 1800, 120), mode("2", 2880, 1800, 60), mode("3", 1920, 1200, 120),
                      mode("4", 1920, 1200, 59.88), mode("5", 2880, 1800, 48)]
        };
        for (let k in extra || {}) o[k] = extra[k];
        return o;
    }

    function test_batteryModePicksNearest60AtSameSize() {
        compare(RefreshRate.batteryMode(panel("1")), "2");
        compare(RefreshRate.batteryMode(panel("3")), "4");
    }

    function test_batteryModeLeaves60Alone() {
        compare(RefreshRate.batteryMode(panel("2")), "");
        compare(RefreshRate.batteryMode(panel("4")), "");
        compare(RefreshRate.batteryMode(panel("5")), "");
    }

    function test_batteryModeWithoutSlowerMode() {
        compare(RefreshRate.batteryMode({ "currentModeId": "1", "modes": [mode("1", 1920, 1080, 144)] }), "");
    }

    function test_acModeRestoresRemembered() {
        compare(RefreshRate.acMode(panel("2"), { "from": 120, "to": 60 }), "1");
    }

    function test_acModeStaysAtRememberedRate() {
        compare(RefreshRate.acMode(panel("2"), { "from": 60, "to": 60 }), "");
    }

    function test_acModeFollowsResolutionChange() {
        // The resolution was changed on battery, so restore the rate at the new size
        compare(RefreshRate.acMode(panel("4"), { "from": 120, "to": 60 }), "3");
    }

    function test_acModeRespectsHandChange() {
        // No longer at the rate it was lowered to, so someone else chose this one
        compare(RefreshRate.acMode(panel("5"), { "from": 120, "to": 60 }), "");
    }

    function test_acModeWithoutMemoryStays() {
        compare(RefreshRate.acMode(panel("2"), undefined), "");
        compare(RefreshRate.acMode(panel("1"), undefined), "");
    }

    function test_planLowersAndRemembers() {
        let p = RefreshRate.plan([panel("1")], true, {});
        compare(p.changes, [{ "name": "eDP-1", "modeId": "2" }]);
        compare(p.remembered, { "eDP-1": { "from": 120, "to": 60 } });
    }

    function test_planKeepsFirstMemory() {
        let memory = { "eDP-1": { "from": 120, "to": 60 } };
        let p = RefreshRate.plan([panel("2")], true, memory);
        compare(p.changes, []);
        compare(p.remembered, memory);
    }

    function test_planRelowerKeepsOriginalRate() {
        // Raised by hand on battery, then lowered again by the next check
        let p = RefreshRate.plan([panel("1")], true, { "eDP-1": { "from": 90, "to": 60 } });
        compare(p.remembered, { "eDP-1": { "from": 90, "to": 60 } });
    }

    function test_planRestoresAndForgets() {
        let p = RefreshRate.plan([panel("2")], false, { "eDP-1": { "from": 120, "to": 60 } });
        compare(p.changes, [{ "name": "eDP-1", "modeId": "1" }]);
        compare(p.remembered, {});
    }

    function test_planLeavesPanelAtUserRateOnAc() {
        // Set to 60 Hz by the user, never lowered by this feature (#130)
        let p = RefreshRate.plan([panel("2")], false, {});
        compare(p.changes, []);
    }

    function test_planKeepsMemoryOfSkippedPanels() {
        let memory = { "eDP-1": { "from": 120, "to": 60 }, "eDP-2": { "from": 144, "to": 60 } };
        compare(RefreshRate.plan([panel("2", { "enabled": false })], false, memory).remembered, memory);
        compare(RefreshRate.plan([panel("2", { "enabled": false })], true, memory).remembered, memory);
        compare(RefreshRate.plan([], false, memory).remembered, memory);
    }

    function test_planRelowersAfterLateBatteryAnswer() {
        // A check before UPower answers sees AC and raises the panel, then the queued check sees battery
        let memory = { "eDP-1": { "from": 120, "to": 60 } };
        let raised = RefreshRate.plan([panel("2")], false, memory);
        compare(raised.changes, [{ "name": "eDP-1", "modeId": "1" }]);
        let p = RefreshRate.plan([panel("1")], true, raised.remembered);
        compare(p.changes, [{ "name": "eDP-1", "modeId": "2" }]);
        compare(p.remembered, memory);
    }

    function test_nearestMode() {
        compare(RefreshRate.nearestMode([mode("1", 1, 1, 120), mode("2", 1, 1, 59.88)], 60).id, "2");
        compare(RefreshRate.nearestMode([mode("1", 1, 1, 61), mode("2", 1, 1, 59)], 60).id, "1");
        compare(RefreshRate.nearestMode([], 60), null);
    }

    function test_shouldCheckWaitsUntilReady() {
        compare(RefreshRate.shouldCheck(false, true, true, {}), false);
        compare(RefreshRate.shouldCheck(true, true, true, {}), true);
    }

    function test_shouldCheckNeedsKscreenDoctor() {
        compare(RefreshRate.shouldCheck(true, false, true, {}), false);
    }

    function test_shouldCheckRestoresAfterSettingIsOff() {
        compare(RefreshRate.shouldCheck(true, true, false, {}), false);
        compare(RefreshRate.shouldCheck(true, true, false, { "eDP-1": { "from": 120, "to": 60 } }), true);
    }

    function test_parseRemembered() {
        compare(RefreshRate.parseRemembered('{"eDP-1":{"from":120,"to":60}}'), { "eDP-1": { "from": 120, "to": 60 } });
        compare(RefreshRate.parseRemembered('{"eDP-1":"1","eDP-2":{"from":120}}'), {});
        compare(RefreshRate.parseRemembered("not json"), {});
        compare(RefreshRate.parseRemembered(""), {});
        compare(RefreshRate.parseRemembered("null"), {});
    }

    function test_planSkipsExternalAndDisabled() {
        let p = RefreshRate.plan([panel("1", { "type": 14, "name": "DP-1" }), panel("1", { "enabled": false })], true, {});
        compare(p.changes, []);
    }

    function test_commandArgs() {
        compare(RefreshRate.commandArgs([{ "name": "eDP-1", "modeId": "2" }]), ["output.eDP-1.mode.2"]);
    }
}
