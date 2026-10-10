import QtQuick
import QtTest
import "../services/clipboardHistory.js" as History

TestCase {
    name: "ClipboardHistory"

    readonly property var src: ({ "app": "firefox", "title": "Firefox" })

    function rec(text, extra) {
        return Object.assign({ "text": text, "kind": "text", "sensitive": false, "size": text.length, "chars": text.length, "lines": 1, "time": 1000 }, extra || {});
    }

    function test_addsNewestFirst() {
        let h = History.addCopy([], rec("a"), src, 1);
        h = History.addCopy(h, rec("b"), src, 2);
        compare(h.map(e => e.text), ["b", "a"]);
        compare(h[0].count, 1);
        compare(h[0].app, "firefox");
    }

    function test_repeatedCopyMovesToFrontAndCounts() {
        let h = History.addCopy([], rec("a"), src, 1);
        h = History.addCopy(h, rec("b"), src, 2);
        h = History.addCopy(h, rec("a", { "time": 5000 }), { "app": "kate", "title": "Kate" }, 3);
        compare(h.map(e => e.text), ["a", "b"]);
        compare(h[0].count, 2);
        compare(h[0].id, 1);
        compare(h[0].firstTime, 1000);
        compare(h[0].time, 5000);
        compare(h[0].appTitle, "Kate");
    }

    function test_repeatedCopyKeepsPin() {
        let h = History.addCopy([], rec("a"), src, 1);
        h[0].pinned = true;
        h = History.addCopy(h, rec("a"), src, 2);
        verify(h[0].pinned);
    }

    function test_trimDropsOldestUnpinned() {
        let h = [];
        for (let i = 0; i < 4; i++) h = History.addCopy(h, rec("t" + i), src, i);
        h[3].pinned = true; // oldest, t0
        h = History.trim(h, 3);
        compare(h.map(e => e.text), ["t3", "t2", "t0"]);
    }

    function test_expireSensitive() {
        let h = History.addCopy([], rec("tok", { "sensitive": true, "time": 1000 }), src, 1);
        h = History.addCopy(h, rec("plain", { "time": 1000 }), src, 2);
        compare(History.expireSensitive(h, 30000, 60).length, 2);
        compare(History.expireSensitive(h, 61000, 60).map(e => e.text), ["plain"]);
        compare(History.expireSensitive(h, 999999, 0).length, 2);
        h[1].pinned = true;
        compare(History.expireSensitive(h, 61000, 60).length, 2);
    }

    function test_ignoredApp() {
        verify(History.isIgnoredApp("KeePassXC", ["keepassxc"]));
        verify(!History.isIgnoredApp("", ["keepassxc"]));
        verify(!History.isIgnoredApp("kate", ["keepassxc"]));
    }

    function test_viewFilterSearchAndPinOrder() {
        let h = History.addCopy([], rec("alpha"), src, 1);
        h = History.addCopy(h, rec("https://x.y", { "kind": "url" }), src, 2);
        h = History.addCopy(h, rec("secretvalue", { "sensitive": true }), src, 3);
        h[3 - 1].pinned = true; // alpha
        compare(History.view(h, "", "all").map(e => e.text), ["alpha", "secretvalue", "https://x.y"]);
        compare(History.view(h, "", "url").map(e => e.text), ["https://x.y"]);
        compare(History.view(h, "", "pinned").map(e => e.text), ["alpha"]);
        compare(History.view(h, "ALP", "all").map(e => e.text), ["alpha"]);
        compare(History.view(h, "firefox", "all").length, 2); // app title, sensitive excluded
        compare(History.view(h, "secret", "all").length, 0);
    }

    function test_preview() {
        compare(History.preview("a \n\t b", 20), "a b");
        compare(History.preview("abcdefghij", 5), "abcd…");
    }

    function test_format() {
        compare(History.formatSize(512), "512 B");
        compare(History.formatSize(2048), "2.0 KB");
        compare(History.formatAge(1000, 1000), "just now");
        compare(History.formatAge(0, 120000), "2 min ago");
        compare(History.formatAge(0, 7200000), "2 h ago");
    }
}
