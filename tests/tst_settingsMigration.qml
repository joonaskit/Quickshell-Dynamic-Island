import QtQuick
import QtTest
import "../services/settingsMigration.js" as SettingsMigration

TestCase {
    name: "SettingsMigration"

    readonly property var ids: ["calendar", "timer", "media", "audioOutput", "appMixer", "volume", "brightness"]

    function test_emptyOrInvalidData() {
        compare(SettingsMigration.widgetStates({}, ids), {});
        compare(SettingsMigration.widgetStates(null, ids), {});
        compare(SettingsMigration.widgetStates("not an object", ids), {});
    }

    function test_readsWidgetsMap() {
        let data = { "widgets": { "calendar": false, "timer": true } };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": false, "timer": true });
    }

    // Every legacy key must map to its widget, including the two whose names
    // differ from the widget id (AudioSink -> audioOutput, AppMixer -> appMixer)
    function test_migratesEveryLegacyKey() {
        let data = {
            "showExpandedCalendar": false,
            "showExpandedTimer": false,
            "showExpandedMedia": false,
            "showExpandedAudioSink": false,
            "showExpandedAppMixer": false,
            "showExpandedVolume": false,
            "showExpandedBrightness": false
        };
        let states = SettingsMigration.widgetStates(data, ids);
        compare(Object.keys(states).length, ids.length);
        for (let i = 0; i < ids.length; i++) {
            verify(states[ids[i]] === false, ids[i] + " should be migrated as disabled");
        }
    }

    function test_legacyKeysKeepTrueAndFalse() {
        let data = { "showExpandedCalendar": true, "showExpandedMedia": false };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": true, "media": false });
    }

    function test_widgetsMapWinsOverLegacyKey() {
        let data = { "showExpandedCalendar": false, "widgets": { "calendar": true } };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": true });
    }

    function test_legacyKeyFillsGapsInWidgetsMap() {
        let data = { "showExpandedTimer": false, "widgets": { "calendar": false } };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": false, "timer": false });
    }

    function test_unknownWidgetIdsAreDropped() {
        let data = { "widgets": { "calendar": false, "removedWidget": true } };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": false });
    }

    function test_widgetsWithoutLegacyKey() {
        let data = { "showExpandedCalendar": false, "widgets": { "weather": false } };
        compare(SettingsMigration.widgetStates(data, ["weather", "notes"]), { "weather": false });
    }

    function test_valuesAreCoercedToBool() {
        let data = { "showExpandedTimer": 0, "widgets": { "calendar": 1, "media": "" } };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": true, "timer": false, "media": false });
    }

    function test_invalidWidgetsValueFallsBackToLegacyKeys() {
        let data = { "showExpandedCalendar": false, "widgets": "broken" };
        compare(SettingsMigration.widgetStates(data, ids), { "calendar": false });
    }

    // The unused showExpandedNotifications key from older configs is ignored
    function test_ignoresDroppedNotificationsKey() {
        compare(SettingsMigration.widgetStates({ "showExpandedNotifications": false }, ids), {});
    }
}
