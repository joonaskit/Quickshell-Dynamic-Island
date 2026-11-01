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
        compare(RefreshRate.acMode(panel("2"), "1"), "1");
        compare(RefreshRate.acMode(panel("1"), "1"), "");
    }

    function test_acModeIgnoresRememberedAtOtherSize() {
        // The resolution was changed on battery, so go to the fastest mode at the new size
        compare(RefreshRate.acMode(panel("4"), "1"), "3");
    }

    function test_acModeWithoutMemoryRaises60() {
        compare(RefreshRate.acMode(panel("2"), undefined), "1");
        compare(RefreshRate.acMode(panel("1"), undefined), "");
    }

    function test_planLowersAndRemembers() {
        let p = RefreshRate.plan([panel("1")], true, {});
        compare(p.changes, [{ "name": "eDP-1", "modeId": "2" }]);
        compare(p.remembered, { "eDP-1": "1" });
    }

    function test_planKeepsFirstMemory() {
        let p = RefreshRate.plan([panel("2")], true, { "eDP-1": "1" });
        compare(p.changes, []);
        compare(p.remembered, { "eDP-1": "1" });
    }

    function test_planRestoresAndForgets() {
        let p = RefreshRate.plan([panel("2")], false, { "eDP-1": "1" });
        compare(p.changes, [{ "name": "eDP-1", "modeId": "1" }]);
        compare(p.remembered, {});
    }

    function test_planSkipsExternalAndDisabled() {
        let p = RefreshRate.plan([panel("1", { "type": 14, "name": "DP-1" }), panel("1", { "enabled": false })], true, {});
        compare(p.changes, []);
    }

    function test_commandArgs() {
        compare(RefreshRate.commandArgs([{ "name": "eDP-1", "modeId": "2" }]), ["output.eDP-1.mode.2"]);
    }
}
