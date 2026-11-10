import QtQuick
import QtTest
import "../dial/dialLogic.js" as Dial

TestCase {
    name: "DialLogic"

    readonly property var apps: [
        { "id": "b", "name": "Browser", "categories": ["Network", "WebBrowser"] },
        { "id": "a", "name": "alpha editor", "categories": ["Utility", "Development"] },
        { "id": "c", "name": "Calc", "categories": ["Qt", "Utility"] },
        { "id": "d", "name": "Odd one", "categories": [] }
    ]

    function names(list) {
        return list.map(a => a.name);
    }

    function test_groupIsFirstMappedCategory() {
        compare(Dial.groupOf(["Qt", "Network"]), "Internet");
        compare(Dial.groupOf(["Utility", "Development"]), "Utilities");
        compare(Dial.groupOf(["Qt"]), "Utilities");
        compare(Dial.groupOf([]), "Utilities");
    }

    function test_allIsSortedIgnoringCase() {
        compare(names(Dial.itemsFor(1, apps, [])), ["alpha editor", "Browser", "Calc", "Odd one"]);
    }

    function test_groupFilters() {
        compare(names(Dial.itemsFor(4, apps, [])), ["Browser"]);
        compare(names(Dial.itemsFor(10, apps, [])), ["alpha editor", "Calc", "Odd one"]);
    }

    function test_pinnedKeepsPinOrderAndSkipsUninstalled() {
        compare(names(Dial.itemsFor(0, apps, ["c", "gone", "b"])), ["Calc", "Browser"]);
        compare(Dial.itemsFor(0, apps, []), []);
    }

    function test_recentAndFrequentUseLaunchHistory() {
        compare(Dial.itemsFor(2, apps, [], {}), []);
        let usage = { "a": { "count": 5, "last": 10 }, "c": { "count": 1, "last": 30 }, "b": { "count": 5, "last": 20 }, "gone": { "count": 9, "last": 99 } };
        compare(names(Dial.itemsFor(2, apps, [], usage)), ["Calc", "Browser", "alpha editor"]);
        compare(names(Dial.itemsFor(3, apps, [], usage)), ["Browser", "alpha editor", "Calc"]);
    }

    function test_historyIsCapped() {
        let many = [];
        let usage = {};
        for (let i = 0; i < 30; i++) {
            many.push({ "id": "app" + i, "name": "App " + i, "categories": [] });
            usage["app" + i] = { "count": 1, "last": i };
        }
        compare(Dial.itemsFor(2, many, [], usage).length, 16);
    }

    function test_middle() {
        compare(Dial.middle(0), -1);
        compare(Dial.middle(1), 0);
        compare(Dial.middle(4), 1);
        compare(Dial.middle(5), 2);
    }

    function test_pointDownIsBelowCentre() {
        let p = Dial.point(345, 90);
        verify(Math.abs(p.x) < 0.001);
        compare(Math.round(p.y), 345);
    }

    function test_ringOpacity() {
        compare(Dial.ringOpacity(3), 1);
        compare(Dial.ringOpacity(4), 0.35);
        compare(Dial.ringOpacity(5), 0);
    }

    function test_thumbSpan() {
        let all = Dial.thumbSpan(0, 40);
        compare(all.from, 150);
        verify(all.to < all.from);
        let end = Dial.thumbSpan(39, 40);
        compare(end.to, 30);
        compare(Dial.thumbSpan(0, 0).from, 150);
    }

    // ----- Search -----

    readonly property var searchApps: [
        { "id": "k", "name": "Kate", "genericName": "Text Editor" },
        { "id": "t", "name": "Notepad Kate Tool", "genericName": "" },
        { "id": "e", "name": "Writer", "genericName": "Kate-like editor" },
        { "id": "x", "name": "Other", "genericName": "" },
        { "id": "k2", "name": "Katarina", "genericName": "" }
    ]

    function test_matchAppsRanksPrefixThenSubstringThenGenericName() {
        compare(names(Dial.matchApps(searchApps, "kat", {})), ["Katarina", "Kate", "Notepad Kate Tool", "Writer"]);
        compare(Dial.matchApps(searchApps, "  ", {}), []);
    }

    function test_matchAppsPutsUsedAppsFirst() {
        // Alphabetical puts Katarina first; launching Kate more often moves it up
        let usage = { "k": { "count": 9, "last": 1 }, "k2": { "count": 2, "last": 1 } };
        compare(names(Dial.matchApps(searchApps, "kat", usage)).slice(0, 2), ["Kate", "Katarina"]);
        // A launched substring match beats an unused prefix match
        compare(names(Dial.matchApps(searchApps, "kat", { "t": { "count": 1, "last": 1 } })).slice(0, 2), ["Notepad Kate Tool", "Katarina"]);
    }

    function test_matchAppsPutsPinnedFirst() {
        let usage = { "k": { "count": 9, "last": 1 } };
        compare(names(Dial.matchApps(searchApps, "kat", usage, ["k2"])).slice(0, 2), ["Katarina", "Kate"]);
        // A pinned app that does not match is not pulled in, and a generic-name match stays last
        compare(names(Dial.matchApps(searchApps, "kat", {}, ["x", "e"]))[3], "Writer");
        compare(names(Dial.matchApps(searchApps, "kat", {}, ["x"])).indexOf("Other"), -1);
    }

    function test_arrangePutsBestInTheMiddle() {
        let hits = ["a", "b", "c", "d", "e"].map(n => ({ "name": n }));
        let arranged = Dial.arrange(hits);
        compare(arranged.map(h => h.name), ["e", "c", "a", "b", "d"]);
        compare(arranged[Dial.middle(arranged.length)].name, "a");
        let four = Dial.arrange(hits.slice(0, 4));
        compare(four[Dial.middle(4)].name, "a");
    }

    function test_everythingPutsPrefixesFirst() {
        let apps = [{ "name": "My Kate" }];
        let settings = [{ "name": "Kate settings" }];
        let files = [{ "name": "katefile" }, { "name": "other kate" }];
        compare(Dial.scopeHits(0, "kate", apps, settings, files).map(h => h.name), ["Kate settings", "katefile", "My Kate", "other kate"]);
        compare(Dial.scopeHits(3, "kate", apps, settings, files).length, 2);
        compare(Dial.scopeHits(2, "kate", apps, settings, files).length, 1);
    }

    function test_scopeLabelsCount() {
        compare(Dial.scopeLabels([1, 2], [3], []), ["Everything 3", "Apps 2", "Settings 1", "Files 0"]);
    }
}
