import QtQuick
import QtTest
import "../dial/dialLogic.js" as Dial
import "../dial/dialPages.js" as Pages

TestCase {
    name: "DialPages"

    function test_everyPageIconHasAPage() {
        ["nightLight", "hue", "notification", "clipboard", "kdeConnect", "usb", "gameMode"].forEach(id => compare(Dial.pageFor(id), id));
    }

    function test_nightTemperatureSlider() {
        compare(Pages.kelvinAt(0, 1000, 6500), 1000);
        compare(Pages.kelvinAt(1, 1000, 6500), 6500);
        compare(Pages.kelvinAt(0.5, 1000, 6500), 3800);
        compare(Pages.kelvinAt(2, 1000, 6500), 6500);
        fuzzyCompare(Pages.levelOf(3750, 1000, 6500), 0.5, 0.001);
        compare(Pages.levelOf(9000, 1000, 6500), 1);
        // One wheel step is 100 K
        let level = Pages.levelOf(4500, 1000, 6500);
        compare(Pages.kelvinAt(level - Pages.SLIDER_STEP.nightLight, 1000, 6500), 4400);
        compare(Pages.kelvinAt(level + Pages.SLIDER_STEP.nightLight, 1000, 6500), 4600);
    }

    function test_nightLightItems() {
        compare(Pages.nightLightItems(false, "DarkLight", "22:00", "07:00").length, 1);
        let items = Pages.nightLightItems(true, "Constant", "22:00", "07:00");
        compare(items.map(i => i.id), ["iconSettings", "night:DarkLight", "night:Constant", "night:Custom"]);
        verify(items[2].lit);
        verify(!items[1].lit);
        compare(items[3].sub, "22:00 – 07:00");
        compare(Dial.pageFocus("nightLight", items), 2);
        let custom = Pages.nightLightItems(true, "Custom", "22:00", "07:00");
        compare(custom[4].card, "nightLight");
    }

    function test_nightLightStatus() {
        let s = { "available": true, "switchedOn": true, "custom": false, "inWindow": false, "scheduleStart": "22:00",
            "scheduleEnd": "07:00", "running": true, "currentTemperature": 4500, "daylight": false };
        compare(Pages.nightLightStatus(s), "Tinting at 4500 K");
        compare(Pages.nightLightStatus(Object.assign({}, s, { "running": false, "daylight": true })), "On, waiting for the evening");
        compare(Pages.nightLightStatus(Object.assign({}, s, { "custom": true })), "On, starts at 22:00");
        compare(Pages.nightLightStatus(Object.assign({}, s, { "custom": true, "inWindow": true })), "Tinting until 07:00");
        compare(Pages.nightLightStatus(Object.assign({}, s, { "switchedOn": false })), "Off");
        compare(Pages.nightLightStatus(Object.assign({}, s, { "available": false })), "Not available in this session");
    }

    readonly property var lamp: ({ "id": "a", "name": "Desk", "on": true, "hasBrightness": true, "brightness": 42.4,
        "hasColorTemp": true, "mirek": 500, "mirekMin": 153, "mirekMax": 500 })

    function test_hueRing() {
        compare(Pages.hueRing([]), ["Hue"]);
        compare(Pages.hueRing([lamp, { "id": "b", "name": "Sofa" }]), ["Desk", "Sofa"]);
        compare(Pages.hueIndex([{ "id": "b" }, lamp], lamp), 1);
        compare(Pages.hueIndex([lamp], null), 0);
    }

    function test_hueItems() {
        compare(Pages.hueItems(null, "").map(i => i.id), ["hueBridge"]);
        let items = Pages.hueItems(lamp, "a");
        compare(items.map(i => i.id), ["hueBridge", "hueFavourite", "huePower", "hueWhite:Warm", "hueWhite:Neutral", "hueWhite:Cool"]);
        verify(items[1].lit);
        verify(items[2].lit);
        compare(items[2].name, "On");
        // The warm white is the one the lamp shows
        verify(items[3].lit);
        verify(!items[5].lit);
        compare(items[3].sub, "2000 K");
        compare(items[5].mirek, 153);
        compare(Dial.pageFocus("hue", items), 2);
        let plain = Pages.hueItems(Object.assign({}, lamp, { "hasColorTemp": false, "on": false }), "");
        compare(plain.length, 3);
        compare(plain[2].name, "Off");
        verify(!plain[1].lit);
    }

    function test_hueReadout() {
        compare(Pages.hueTitle(null), "Philips Hue");
        compare(Pages.hueTitle(lamp), "42%");
        compare(Pages.hueTitle(Object.assign({}, lamp, { "on": false })), "Off");
        compare(Pages.hueTitle(Object.assign({}, lamp, { "hasBrightness": false })), "On");
        compare(Pages.hueStatus("bridge unreachable", true, lamp), "bridge unreachable");
        compare(Pages.hueStatus("", false, null), "Connecting…");
        compare(Pages.hueStatus("", true, null), "No lights found");
        compare(Pages.hueStatus("", true, lamp), "Desk");
    }

    readonly property var notes: [
        { "id": 3, "appName": "Mail", "appIcon": "mail", "summary": "Hello", "body": "<b>Hi</b>  there", "time": "12:01" },
        { "id": 2, "appName": "", "summary": "", "body": "", "time": "" },
        { "id": 1, "appName": "Mail", "summary": "Older", "body": "", "time": "11:00" }
    ]
    readonly property var groups: [
        { "appName": "Mail", "items": [notes[0], notes[2]] },
        { "appName": "System", "items": [notes[1]] }
    ]

    function test_notificationRing() {
        compare(Pages.notificationRing([]), ["All 0"]);
        compare(Pages.notificationRing(groups), ["All 3", "Mail 2", "System 1"]);
        compare(Pages.notificationIndex(groups, ""), 0);
        compare(Pages.notificationIndex(groups, "System"), 2);
        compare(Pages.notificationIndex(groups, "Gone"), 0);
    }

    function test_notificationItems() {
        let empty = Pages.notificationItems([], "", true);
        compare(empty.map(i => i.id), ["dnd"]);
        verify(empty[0].lit);
        compare(Dial.pageFocus("notification", empty), 0);

        let all = Pages.notificationItems(notes, "", false);
        compare(all.map(i => i.id), ["clearNotifications", "dnd", "notif:3", "notif:2", "notif:1"]);
        verify(all[0].confirm);
        compare(all[2].kind, "notification");
        compare(all[2].sub, "Mail · 12:01");
        compare(all[3].name, "Notification");
        compare(all[3].app, "System");
        compare(Dial.pageFocus("notification", all), 2);

        let system = Pages.notificationItems(notes, "System", false);
        compare(system.map(i => i.id), ["clearNotifications", "dnd", "notif:2"]);
        compare(system[0].name, "Clear These");
        // One notification needs no second click
        verify(!system[0].confirm);
    }

    function test_notificationReadout() {
        compare(Pages.notificationTitle(0), "No notifications");
        compare(Pages.notificationTitle(1), "1 notification");
        compare(Pages.notificationTitle(4), "4 notifications");
        let all = Pages.notificationItems(notes, "", false);
        compare(Pages.notificationStatus(all[2], false), "Hi there");
        compare(Pages.notificationStatus(all[4], false), "Older");
        compare(Pages.notificationStatus(all[1], true), "Do Not Disturb is on");
        compare(Pages.notificationStatus(undefined, false), "Banners are on");
    }

    function test_clipboardItems() {
        compare(Pages.CLIPBOARD_RING.length, Pages.CLIPBOARD_FILTERS.length);
        let empty = Pages.clipboardItems([], true, false);
        compare(empty.map(i => i.id), ["clipboardWindow", "incognito"]);
        verify(empty[1].lit);
        compare(Dial.pageFocus("clipboard", empty), 1);

        let items = Pages.clipboardItems([
            { "id": 5, "kind": "url", "pinned": true, "sensitive": false, "label": "example.org", "age": "2 h ago" },
            { "id": 4, "kind": "text", "pinned": false, "sensitive": true, "label": "hunter2", "age": "just now" }
        ], false, true);
        compare(items.map(i => i.id), ["clipboardWindow", "incognito", "clearClipboard", "clip:5", "clip:4"]);
        compare(items[3].sub, "Pinned · 2 h ago");
        compare(items[3].icon, "window");
        // A credential is not shown
        compare(items[4].name, "Hidden");
        compare(items[4].icon, "lock");
        compare(Dial.pageFocus("clipboard", items), 3);

        let many = [];
        for (let i = 0; i < 40; i++) many.push({ "id": i, "kind": "text", "label": "x", "age": "" });
        compare(Pages.clipboardItems(many, false, true).length, 3 + Pages.CLIPBOARD_ENTRIES);
    }

    function test_clipboardStatus() {
        let c = { "hiddenReason": "", "hiddenText": "Hidden by app", "currentFiles": [], "currentBinaryType": "", "currentText": "", "currentSensitive": false };
        compare(Pages.clipboardStatus(c, ""), "Clipboard is empty");
        compare(Pages.clipboardStatus(Object.assign({}, c, { "currentText": "abc" }), "abc"), "abc");
        compare(Pages.clipboardStatus(Object.assign({}, c, { "currentText": "abc", "currentSensitive": true }), "abc"), "Hidden: looks like a credential");
        compare(Pages.clipboardStatus(Object.assign({}, c, { "currentBinaryType": "image/png" }), ""), "Image on clipboard");
        compare(Pages.clipboardStatus(Object.assign({}, c, { "currentFiles": ["/a", "/b"] }), ""), "2 files on clipboard");
        compare(Pages.clipboardStatus(Object.assign({}, c, { "hiddenReason": "app" }), ""), "Hidden by app");
    }

    readonly property var phone: ({ "id": "p", "name": "Pixel", "reachable": true, "hasBattery": true, "charge": 80, "charging": true,
        "canPing": true, "canRing": false, "canClipboard": true, "canShare": true })

    function test_kdeConnect() {
        compare(Pages.kdeRing([]), ["KDE Connect"]);
        compare(Pages.kdeRing([phone]), ["Pixel"]);
        compare(Pages.kdeItems(null).map(i => i.id), ["iconSettings"]);
        compare(Pages.kdeItems(Object.assign({}, phone, { "reachable": false })).length, 1);
        let items = Pages.kdeItems(phone);
        compare(items.map(i => i.id), ["iconSettings", "kdePing", "kdeClipboard", "kdeFile", "kdeText"]);
        compare(items[4].card, "kdeConnect");
        // Send File closes the dial for the file picker
        verify(!items[3].stay);
        compare(Dial.pageFocus("kdeConnect", items), 1);

        compare(Pages.kdeStatus(false, phone, ""), "KDE Connect is not running");
        compare(Pages.kdeStatus(true, null, ""), "No paired devices");
        compare(Pages.kdeStatus(true, phone, "Ping sent"), "Ping sent");
        compare(Pages.kdeStatus(true, phone, ""), "Battery 80% · Charging");
        compare(Pages.kdeStatus(true, Object.assign({}, phone, { "reachable": false }), ""), "Not connected. Open KDE Connect on the phone");
    }

    function test_drives() {
        compare(Pages.driveItems([], "").map(i => i.id), ["rescanDrives"]);
        let devices = [
            { "path": "/dev/sda", "title": "Stick", "partitions": [
                { "path": "/dev/sda1", "title": "Photos", "isMounted": true, "mountpoint": "/run/media/u/Photos", "usePercent": 40 },
                { "path": "/dev/sda2", "label": "Spare", "isMounted": false, "sizeFormatted": "8.0 GB" }
            ] },
            { "path": "/dev/sdb", "title": "Card", "isMounted": false, "sizeFormatted": "32 GB" }
        ];
        let items = Pages.driveItems(devices, "/dev/sda2");
        compare(items.map(i => i.id), ["rescanDrives", "drive:/dev/sda1", "drive:/dev/sda2", "drive:/dev/sdb"]);
        compare(items[1].sub, "40% used");
        verify(items[1].lit);
        // Opening a mounted drive closes the dial; mounting does not
        verify(!items[1].stay);
        verify(items[2].stay);
        compare(items[2].sub, "Working…");
        compare(items[2].parent, "/dev/sda");
        compare(items[3].sub, "32 GB · Not mounted");
        compare(items[3].parent, "/dev/sdb");
        compare(Dial.pageFocus("usb", items), 1);

        compare(Pages.driveTitle(0), "No drives");
        compare(Pages.driveTitle(2), "2 drives");
        compare(Pages.driveStatus(0, 0, "", ""), "Connect a USB drive or external disk");
        compare(Pages.driveStatus(2, 1, "", ""), "1 mounted");
        compare(Pages.driveStatus(2, 0, "", ""), "None mounted");
        compare(Pages.driveStatus(2, 0, "/dev/sda1", "Mounting…"), "Mounting…");
    }

    function test_gameMode() {
        let items = Pages.gameItems([{ "pid": 7, "name": "doom" }]);
        compare(items.map(i => i.id), ["iconSettings", "game:7"]);
        verify(items[1].lit);
        compare(Pages.gameTitle(false, false), "GameMode");
        compare(Pages.gameTitle(true, true), "Active");
        compare(Pages.gameTitle(true, false), "Idle");
        compare(Pages.gameStatus(false, 0, false), "Not installed (sudo dnf install gamemode)");
        compare(Pages.gameStatus(true, 2, true), "For 2 games");
        compare(Pages.gameStatus(true, 0, true), "Forced on");
        compare(Pages.gameStatus(true, 0, false), "Starts with a game that asks for it");
    }
}
