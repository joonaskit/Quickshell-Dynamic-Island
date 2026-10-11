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

    function test_orderWithoutSavedListIsRegistryOrder() {
        compare(SettingsMigration.savedOrder(undefined, ids), ids);
        compare(SettingsMigration.savedOrder([], ids), ids);
        compare(SettingsMigration.savedOrder("broken", ids), ids);
    }

    function test_orderReadsSavedList() {
        let saved = ["media", "timer", "calendar", "brightness", "volume", "appMixer", "audioOutput"];
        compare(SettingsMigration.savedOrder(saved, ids), saved);
    }

    // A widget added after the order was saved goes at the end, in registry order
    function test_orderAppendsMissingIds() {
        compare(SettingsMigration.savedOrder(["media", "calendar"], ids),
                ["media", "calendar", "timer", "audioOutput", "appMixer", "volume", "brightness"]);
    }

    function test_orderDropsUnknownAndDuplicateIds() {
        compare(SettingsMigration.savedOrder(["removedWidget", "media", 7, "media", null], ["calendar", "media"]),
                ["media", "calendar"]);
    }

    readonly property var groups: ({ "calendar": "cards", "timer": "cards", "media": "cards", "volume": "controls", "brightness": "controls" })
    readonly property var groupedOrder: ["calendar", "timer", "media", "volume", "brightness"]

    function test_moveSwapsWithNeighbour() {
        compare(SettingsMigration.movedOrder(groupedOrder, "timer", -1, groups),
                ["timer", "calendar", "media", "volume", "brightness"]);
        compare(SettingsMigration.movedOrder(groupedOrder, "timer", 1, groups),
                ["calendar", "media", "timer", "volume", "brightness"]);
    }

    function test_moveStopsAtGroupEdges() {
        compare(SettingsMigration.movedOrder(groupedOrder, "calendar", -1, groups), groupedOrder);
        compare(SettingsMigration.movedOrder(groupedOrder, "media", 1, groups), groupedOrder);
        compare(SettingsMigration.movedOrder(groupedOrder, "volume", -1, groups), groupedOrder);
        compare(SettingsMigration.moveTarget(groupedOrder, "media", 1, groups), -1);
        compare(SettingsMigration.moveTarget(groupedOrder, "unknown", 1, groups), -1);
    }

    // Groups may be interleaved in the saved order; a move skips the other group
    function test_moveSkipsOtherGroup() {
        compare(SettingsMigration.movedOrder(["calendar", "volume", "timer"], "calendar", 1, groups),
                ["timer", "volume", "calendar"]);
    }

    function test_moveDoesNotChangeInput() {
        let order = ["calendar", "timer"];
        SettingsMigration.movedOrder(order, "timer", -1, groups);
        compare(order, ["calendar", "timer"]);
    }

    // Status-bar icons use the same functions with their own groups
    function test_statusIconOrderAndMove() {
        let iconIds = ["nightLight", "hue", "wifi", "bluetooth", "battery"];
        let iconGroups = { "nightLight": "widgets", "hue": "widgets", "wifi": "system", "bluetooth": "system", "battery": "system" };
        let order = SettingsMigration.savedOrder(["battery", "hue", "gone"], iconIds);
        compare(order, ["battery", "hue", "nightLight", "wifi", "bluetooth"]);
        compare(SettingsMigration.movedOrder(order, "battery", 1, iconGroups),
                ["wifi", "hue", "nightLight", "battery", "bluetooth"]);
        compare(SettingsMigration.moveTarget(order, "battery", -1, iconGroups), -1);
        compare(SettingsMigration.moveTarget(order, "nightLight", 1, iconGroups), -1);
    }
}
