import QtQuick
import QtTest
import "../services/settingChoices.js" as SettingChoices

TestCase {
    name: "SettingChoices"

    function test_pairValue() {
        compare(SettingChoices.pairValue(false, false), "off");
        compare(SettingChoices.pairValue(false, true), "off");
        compare(SettingChoices.pairValue(true, false), "on");
        compare(SettingChoices.pairValue(true, true), "sub");
    }

    function test_pairSettings() {
        compare(SettingChoices.pairSettings("off"), { "on": false, "sub": null });
        compare(SettingChoices.pairSettings("on"), { "on": true, "sub": false });
        compare(SettingChoices.pairSettings("sub"), { "on": true, "sub": true });
    }

    function test_pairRoundTrip() {
        let values = ["on", "sub"];
        for (let i = 0; i < values.length; i++) {
            let s = SettingChoices.pairSettings(values[i]);
            compare(SettingChoices.pairValue(s.on, s.sub), values[i]);
        }
    }

    function test_topBarMode() {
        compare(SettingChoices.topBarMode(false, false), "island");
        compare(SettingChoices.topBarMode(true, false), "maximized");
        compare(SettingChoices.topBarMode(false, true), "always");
        compare(SettingChoices.topBarMode(true, true), "always");
    }

    function test_topBarRoundTrip() {
        let modes = ["island", "maximized", "always"];
        for (let i = 0; i < modes.length; i++) {
            let s = SettingChoices.topBarSettings(modes[i]);
            compare(SettingChoices.topBarMode(s.morphToTopBarWhenMaximized, s.alwaysTopBar), modes[i]);
        }
    }
}
