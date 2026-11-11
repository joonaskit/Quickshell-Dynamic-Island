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
        compare(names(Dial.itemsFor(Dial.categoryIndex("all"), apps, [])), ["alpha editor", "Browser", "Calc", "Odd one"]);
    }

    function test_groupFilters() {
        compare(names(Dial.itemsFor(5, apps, [])), ["Browser"]);
        compare(names(Dial.itemsFor(11, apps, [])), ["alpha editor", "Calc", "Odd one"]);
    }

    function test_pinnedKeepsPinOrderAndSkipsUninstalled() {
        compare(names(Dial.itemsFor(0, apps, ["c", "gone", "b"])), ["Calc", "Browser"]);
        compare(Dial.itemsFor(0, apps, []), []);
    }

    function test_recentAndFrequentUseLaunchHistory() {
        compare(Dial.itemsFor(Dial.categoryIndex("recent"), apps, [], {}), []);
        let usage = { "a": { "count": 5, "last": 10 }, "c": { "count": 1, "last": 30 }, "b": { "count": 5, "last": 20 }, "gone": { "count": 9, "last": 99 } };
        compare(names(Dial.itemsFor(Dial.categoryIndex("recent"), apps, [], usage)), ["Calc", "Browser", "alpha editor"]);
        compare(names(Dial.itemsFor(Dial.categoryIndex("frequent"), apps, [], usage)), ["Browser", "alpha editor", "Calc"]);
    }

    function test_historyIsCapped() {
        let many = [];
        let usage = {};
        for (let i = 0; i < 30; i++) {
            many.push({ "id": "app" + i, "name": "App " + i, "categories": [] });
            usage["app" + i] = { "count": 1, "last": i };
        }
        compare(Dial.itemsFor(Dial.categoryIndex("recent"), many, [], usage).length, 16);
    }

    function test_windowsListsTheOpenWindows() {
        let windows = [{ "name": "Window one" }, { "name": "Window two" }];
        compare(Dial.CATEGORIES[1].name, "Windows");
        compare(names(Dial.itemsFor(Dial.categoryIndex("windows"), apps, [], {}, windows)), ["Window one", "Window two"]);
        compare(Dial.itemsFor(Dial.categoryIndex("windows"), apps, []), []);
    }

    function test_categoryIndex() {
        compare(Dial.categoryIndex("pinned"), 0);
        compare(Dial.categoryIndex("windows"), 1);
        compare(Dial.categoryIndex("nope"), -1);
    }

    function test_jumpTarget() {
        compare(Dial.jumpTarget("home", 7, 20), 0);
        compare(Dial.jumpTarget("end", 7, 20), 19);
        compare(Dial.jumpTarget("pageUp", 7, 20), 3);
        compare(Dial.jumpTarget("pageDown", 7, 20), 11);
        compare(Dial.jumpTarget("pageUp", 2, 20), 0);
        compare(Dial.jumpTarget("pageDown", 18, 20), 19);
        compare(Dial.jumpTarget("end", 0, 0), 0);
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

    // With this radius one px along the ring is one degree
    readonly property real unitRadius: 180 / Math.PI

    function test_ringAnglesSpacePillsByWidth() {
        let angles = Dial.ringAngles([20, 40, 10], unitRadius, 5);
        compare(angles.length, 3);
        compare(angles[0], 0);
        fuzzyCompare(angles[1], 35, 0.0001);
        fuzzyCompare(angles[2], 65, 0.0001);
        compare(Dial.ringAngles([], unitRadius, 5), []);
    }

    function test_ringAngleAtFollowsThePills() {
        let angles = [0, 35, 65];
        compare(Dial.ringAngleAt(angles, 0), 0);
        compare(Dial.ringAngleAt(angles, 1), 35);
        compare(Dial.ringAngleAt(angles, 1.5), 50);
        compare(Dial.ringAngleAt(angles, 2), 65);
        // Past an end it carries on at the end's own step
        compare(Dial.ringAngleAt(angles, -0.2), -7);
        compare(Dial.ringAngleAt(angles, 2.1), 68);
        compare(Dial.ringAngleAt([], 3), 0);
        compare(Dial.ringAngleAt([0], 0.5), 11);
    }

    function test_ringPositionAtIsTheReverse() {
        let angles = [0, 35, 65];
        [-0.2, 0, 0.4, 1, 1.5, 2, 2.1].forEach(position => {
            fuzzyCompare(Dial.ringPositionAt(angles, Dial.ringAngleAt(angles, position)), position, 0.0001);
        });
        compare(Dial.ringPositionAt([], 20), 0);
    }

    function test_ringOpacity() {
        compare(Dial.ringOpacity(3), 1);
        compare(Dial.ringOpacity(4), 0.35);
        compare(Dial.ringOpacity(5), 0);
        // Fades between whole steps while the ring turns
        fuzzyCompare(Dial.ringOpacity(3.5), 0.675, 0.0001);
        fuzzyCompare(Dial.ringOpacity(4.5), 0.175, 0.0001);
        compare(Dial.ringOpacity(7), 0);
    }

    function test_arcOpacity() {
        compare(Dial.arcOpacity(0), 1);
        compare(Dial.arcOpacity(4), 1);
        compare(Dial.arcOpacity(4.5), 0.5);
        compare(Dial.arcOpacity(5), 0);
        compare(Dial.arcOpacity(9), 0);
    }

    // ----- Turning -----

    function test_wheelNotchIsOneStep() {
        compare(Dial.wheelSteps(0, 120).steps, 1);
        compare(Dial.wheelSteps(0, -120).steps, -1);
        compare(Dial.wheelSteps(0, 360).steps, 3);
    }

    function test_wheelCarriesSmallDeltas() {
        let a = Dial.wheelSteps(0, 50);
        compare(a.steps, 0);
        let b = Dial.wheelSteps(a.carry, 50);
        compare(b.steps, 0);
        let c = Dial.wheelSteps(b.carry, 50);
        compare(c.steps, 1);
        fuzzyCompare(c.carry, 0.25, 0.0001);
        // Turning back uses up the carry first
        compare(Dial.wheelSteps(c.carry, -50).steps, 0);
    }

    function test_wheelZeroDeltaDoesNothing() {
        let r = Dial.wheelSteps(0, 0);
        verify(r.steps === 0);
        compare(r.carry, 0);
    }

    function test_turnDurationGrowsWithDistance() {
        compare(Dial.turnDuration(0.2), 360);
        compare(Dial.turnDuration(1), 360);
        compare(Dial.turnDuration(6), 560);
        compare(Dial.turnDuration(-6), 560);
        compare(Dial.turnDuration(100), 900);
    }

    function test_turnOvershootFadesWithDistance() {
        compare(Dial.turnOvershoot(1), 0.9);
        compare(Dial.turnOvershoot(0.3), 0.9);
        compare(Dial.turnOvershoot(-9), 0.1);
    }

    function test_angleStepGoesTheShortWay() {
        compare(Dial.angleStep(10, 30), 20);
        compare(Dial.angleStep(30, 10), -20);
        compare(Dial.angleStep(170, -170), 20);
        compare(Dial.angleStep(-170, 170), -20);
    }

    function test_dragTurnStopsJustPastTheEnds() {
        compare(Dial.dragTurn(3.4, 10), 3.4);
        compare(Dial.dragTurn(-2, 10), -0.35);
        compare(Dial.dragTurn(20, 10), 9.35);
        compare(Dial.dragTurn(5, 0), 0.35);
    }

    function test_flickVelocity() {
        // Two steps in 50 ms is 40 steps a second
        let samples = [{ "t": 880, "turn": 0 }, { "t": 950, "turn": 5 }, { "t": 1000, "turn": 7 }];
        compare(Dial.flickVelocity(samples, 1000), 40);
        // Older movement is left out, and a pointer that rested has no speed
        compare(Dial.flickVelocity(samples, 1080), 0);
        compare(Dial.flickVelocity([], 1000), 0);
        compare(Dial.flickVelocity([{ "t": 1000, "turn": 1 }, { "t": 1000, "turn": 2 }], 1000), 0);
    }

    function test_flickTarget() {
        compare(Dial.flickTarget(3.4, 0, 20), 3);
        compare(Dial.flickTarget(3.4, 20, 20), 8);
        compare(Dial.flickTarget(3.4, -40, 20), 0);
        compare(Dial.flickTarget(3.4, 400, 20), 19);
        compare(Dial.flickTarget(0.2, 10, 0), 0);
    }

    function test_thumbSpan() {
        let all = Dial.thumbSpan(0, 40);
        compare(all.from, 150);
        verify(all.to < all.from);
        let end = Dial.thumbSpan(39, 40);
        compare(end.to, 30);
        compare(Dial.thumbSpan(0, 0).from, 150);
        // Halfway between two slots the thumb is halfway too
        let between = Dial.thumbSpan(10.5, 40);
        fuzzyCompare(between.from, (Dial.thumbSpan(10, 40).from + Dial.thumbSpan(11, 40).from) / 2, 0.0001);
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

    function test_matchAppsPutsRunningFirst() {
        // Running beats pinned and used; a running app that only matches by generic name stays last
        let usage = { "k": { "count": 9, "last": 1 } };
        compare(names(Dial.matchApps(searchApps, "kat", usage, ["k"], { "t": true })).slice(0, 2), ["Notepad Kate Tool", "Kate"]);
        compare(names(Dial.matchApps(searchApps, "kat", {}, [], { "e": true }))[3], "Writer");
    }

    function test_arrangePutsBestInTheMiddle() {
        let hits = ["a", "b", "c", "d", "e"].map(n => ({ "name": n }));
        let arranged = Dial.arrange(hits);
        compare(arranged.map(h => h.name), ["e", "c", "a", "b", "d"]);
        compare(arranged[Dial.middle(arranged.length)].name, "a");
        let four = Dial.arrange(hits.slice(0, 4));
        compare(four[Dial.middle(4)].name, "a");
    }

    function test_everythingPutsAppsFirst() {
        let apps = [{ "name": "My Kate" }];
        let settings = [{ "name": "Kate settings" }];
        let files = [{ "name": "katefile" }, { "name": "other kate" }];
        compare(Dial.scopeHits(0, "kate", apps, settings, files).map(h => h.name), ["My Kate", "Kate settings", "katefile", "other kate"]);
        compare(Dial.scopeHits(3, "kate", apps, settings, files).length, 2);
        compare(Dial.scopeHits(2, "kate", apps, settings, files).length, 1);
    }

    function test_scopeLabelsCount() {
        compare(Dial.scopeLabels([1, 2], [3], []), ["Everything 3", "Apps 2", "Settings 1", "Files 0"]);
    }

    function test_batteryAndProfileOpenThePowerPage() {
        compare(Dial.pageFor("battery"), "power");
        compare(Dial.pageFor("profile"), "power");
        compare(Dial.pageFor("wifi"), "wifi");
        compare(Dial.pageFor("bluetooth"), "bluetooth");
        compare(Dial.pageFor("hardware"), "hardware");
        compare(Dial.pageFor("mic"), "");
    }

    function test_powerPageStartsOnLock() {
        compare(Dial.POWER_ACTIONS[Dial.pageFocus("power", Dial.POWER_ACTIONS)].id, "lock");
    }

    function test_onlyRestartAndShutDownConfirm() {
        compare(Dial.POWER_ACTIONS.filter(a => a.confirm).map(a => a.id), ["restart", "shutdown"]);
    }

    function test_profileIndexFallsBackToBalanced() {
        compare(Dial.profileIndex("performance"), 2);
        compare(Dial.profileIndex("unknown"), 1);
    }

    function test_batteryTone() {
        compare(Dial.batteryTone(0.05, true), "charging");
        compare(Dial.batteryTone(0.10, false), "critical");
        compare(Dial.batteryTone(0.2, false), "low");
        compare(Dial.batteryTone(0.5, false), "normal");
    }

    function test_batteryStatus() {
        compare(Dial.batteryStatus(false, false, false, 0, 0), "No battery");
        compare(Dial.batteryStatus(true, true, true, 0, 0), "Fully charged");
        compare(Dial.batteryStatus(true, true, false, 2700, 0), "Charging · 45m until full");
        compare(Dial.batteryStatus(true, true, false, 0, 0), "Charging");
        compare(Dial.batteryStatus(true, false, false, 0, 8040), "2h 14m remaining");
        compare(Dial.batteryStatus(true, false, false, 0, 0), "On battery");
    }

    readonly property var networks: [
        { "ssid": "Home", "signal": 80, "inUse": true, "isSecure": true },
        { "ssid": "Cafe", "signal": 40, "inUse": false, "isSecure": false }
    ]

    function test_wifiItemsListNetworksAfterActions() {
        let items = Dial.wifiItems(networks, true);
        compare(items.map(i => i.id), ["wifiSettings", "rescan", "net:Home", "net:Cafe"]);
        compare(items[2].sub, "Connected · Secured");
        compare(items[3].sub, "40%");
        compare(Dial.wifiItems(networks, false).map(i => i.id), ["wifiSettings"]);
    }

    function test_wifiPageStartsOnConnectedNetwork() {
        compare(Dial.pageFocus("wifi", Dial.wifiItems(networks, true)), 2);
        let free = [{ "ssid": "Cafe", "signal": 40 }, { "ssid": "Bar", "signal": 30 }];
        compare(Dial.pageFocus("wifi", Dial.wifiItems(free, true)), 2);
        compare(Dial.pageFocus("wifi", Dial.wifiItems([], false)), 0);
    }

    function test_wifiStatus() {
        compare(Dial.wifiStatus(false, false, "", false, 0, 0), "Turn Wi-Fi on from the ring");
        compare(Dial.wifiStatus(true, false, "Cafe", false, 0, 2), "Connecting to Cafe…");
        compare(Dial.wifiStatus(true, false, "", true, 0, 0), "Scanning…");
        compare(Dial.wifiStatus(true, true, "", false, 80, 2), "Signal 80% · 2 networks");
        compare(Dial.wifiStatus(true, false, "", false, 0, 1), "1 network");
    }

    function test_savedNetworksSkipThePassword() {
        let items = Dial.wifiItems(networks.concat([{ "ssid": "Work", "signal": 60, "isSecure": true }]), true, ["Work"]);
        compare(items.map(i => Dial.needsPassword(i)), [false, false, false, false, false]);
        compare(items[4].sub, "60% · Saved");
        let fresh = Dial.wifiItems([{ "ssid": "Lab", "signal": 50, "isSecure": true }], true, []);
        verify(Dial.needsPassword(fresh[2]));
    }

    function test_wifiStatusNamesAFailedConnect() {
        compare(Dial.wifiStatus(true, false, "", false, 0, 2, "Cafe"), "Could not connect to Cafe");
        compare(Dial.wifiStatus(true, false, "Lab", false, 0, 2, "Cafe"), "Connecting to Lab…");
    }

    readonly property var devices: [
        { "mac": "A", "name": "Buds", "icon": "headphones", "isConnected": true, "battery": 0.55 },
        { "mac": "B", "name": "Mouse", "icon": "bluetooth", "isConnected": false, "battery": -1 }
    ]

    function test_bluetoothItems() {
        let items = Dial.bluetoothItems(devices, true);
        compare(items.map(i => i.id), ["bluetoothSettings", "bt:A", "bt:B"]);
        compare(items.map(i => i.sub), [undefined, "Connected · 55%", "Not connected"]);
        compare(Dial.pageFocus("bluetooth", items), 1);
        compare(Dial.bluetoothItems(devices, false).length, 1);
    }

    function test_bluetoothStatus() {
        compare(Dial.bluetoothStatus(false, false, false, "", -1, 0), "No Bluetooth adapter found");
        compare(Dial.bluetoothStatus(true, false, false, "", -1, 2), "Turn Bluetooth on from the ring");
        compare(Dial.bluetoothStatus(true, true, false, "Buds", -1, 2), "Connecting to Buds…");
        compare(Dial.bluetoothStatus(true, true, false, "", -1, 0), "No paired devices");
        compare(Dial.bluetoothStatus(true, true, true, "", 0.55, 2), "Battery 55% · 2 paired");
        compare(Dial.bluetoothStatus(true, true, false, "", -1, 2), "2 paired");
    }

    readonly property var programs: [
        { "name": "code", "cpu": 1.2, "memMb": 3400 },
        { "name": "firefox", "cpu": 9.5, "memMb": 900 },
        { "name": "kwin_wayland", "cpu": 0.4, "memMb": 224 }
    ]

    function test_hardwareItemsSortByTheRing() {
        compare(Dial.hardwareItems(programs, 0).map(i => i.id), ["systemMonitor", "proc:firefox", "proc:code", "proc:kwin_wayland"]);
        compare(Dial.hardwareItems(programs, 1).map(i => i.id), ["systemMonitor", "proc:code", "proc:firefox", "proc:kwin_wayland"]);
        compare(Dial.hardwareItems(programs, 0)[1].sub, "9.5% CPU");
        compare(Dial.hardwareItems(programs, 1)[1].sub, "3.3 GB");
        compare(Dial.hardwareItems(programs, 1)[3].sub, "224 MB");
        compare(Dial.pageFocus("hardware", Dial.hardwareItems(programs, 0)), 1);
        compare(Dial.pageFocus("hardware", Dial.hardwareItems([], 0)), 0);
    }

    function test_desktopProgramsCannotBeEnded() {
        verify(Dial.canEnd("firefox"));
        verify(!Dial.canEnd("kwin_wayland"));
        verify(!Dial.canEnd("quickshell"));
    }

    function test_hardwareTone() {
        compare(Dial.hardwareTone(0, 95), "critical");
        compare(Dial.hardwareTone(1, 80), "high");
        compare(Dial.hardwareTone(0, 20), "normal");
        compare(Dial.hardwareTone(2, 80), "critical");
        compare(Dial.hardwareTone(2, 65), "high");
        compare(Dial.hardwareTone(2, 50), "normal");
    }

    function test_hardwareReadout() {
        compare(Dial.hardwareTitle(0, 23, 45, 52), "23%");
        compare(Dial.hardwareTitle(2, 23, 45, 0), "No sensor");
        compare(Dial.hardwareStatus(0, 23, 45, 12.1, 31.2, 52), "Memory 45% · 52 °C");
        compare(Dial.hardwareStatus(0, 23, 45, 12.1, 31.2, 0), "Memory 45%");
        compare(Dial.hardwareStatus(1, 23, 45, 12.1, 31.2, 52), "12.1 of 31.2 GB · CPU 23%");
        compare(Dial.hardwareStatus(2, 23, 45, 12.1, 31.2, 52), "CPU 23% · Memory 45%");
    }
}
