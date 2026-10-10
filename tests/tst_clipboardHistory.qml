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

    function img(hash, extra) {
        return Object.assign({ "type": "image", "mime": "image/png", "path": "/run/x/" + hash + ".png", "hash": hash, "size": 100, "time": 1000 }, extra || {});
    }

    function files(list) {
        return { "type": "files", "files": list, "time": 1000 };
    }

    function test_imageRepeatMovesToFront() {
        let h = History.addCopy([], img("h1"), src, 1);
        h = History.addCopy(h, rec("t"), src, 2);
        h = History.addCopy(h, img("h1", { "time": 5000 }), src, 3);
        compare(h.length, 2);
        compare(h[0].type, "image");
        compare(h[0].count, 2);
        compare(h[0].id, 1);
        compare(h[0].kind, "image");
        compare(h[0].sensitive, false);
    }

    function test_differentImagesAreSeparate() {
        let h = History.addCopy([], img("h1"), src, 1);
        h = History.addCopy(h, img("h2"), src, 2);
        compare(h.length, 2);
    }

    function test_filesRepeatAndFolder() {
        let h = History.addCopy([], files(["/home/u/docs/a.txt", "/home/u/docs/b.txt"]), src, 1);
        compare(h[0].dir, "/home/u/docs");
        h = History.addCopy(h, files(["/home/u/docs/a.txt", "/home/u/docs/b.txt"]), src, 2);
        compare(h.length, 1);
        compare(h[0].count, 2);
        h = History.addCopy(h, files(["/home/u/docs/a.txt"]), src, 3);
        compare(h.length, 2);
    }

    function test_commonDir() {
        compare(History.commonDir(["/a/b/c.txt"]), "/a/b");
        compare(History.commonDir(["/a/b/c.txt", "/a/d/e.txt"]), "/a");
        compare(History.commonDir(["/a/b.txt", "/c/d.txt"]), "/");
        compare(History.commonDir(["/a.txt"]), "/");
    }

    function test_textAndImageDoNotCollide() {
        let h = History.addCopy([], rec("abc"), src, 1);
        h = History.addCopy(h, img("abc"), src, 2);
        compare(h.length, 2);
    }

    function test_viewFiltersImagesAndFiles() {
        let h = History.addCopy([], rec("alpha"), src, 1);
        h = History.addCopy(h, img("h1"), src, 2);
        h = History.addCopy(h, files(["/home/u/report.pdf"]), src, 3);
        compare(History.view(h, "", "image").map(e => e.id), [2]);
        compare(History.view(h, "", "files").map(e => e.id), [3]);
        compare(History.view(h, "", "text").map(e => e.id), [1]);
        compare(History.view(h, "report", "all").map(e => e.id), [3]);
        compare(History.view(h, "", "all").length, 3);
    }

    function test_labelsAndThumbs() {
        let h = History.addCopy([], img("h1"), src, 1);
        h = History.addCopy(h, files(["/x/a.txt", "/x/pic.PNG", "/x/c.txt"]), src, 2);
        h = History.addCopy(h, files(["/x/a.txt"]), src, 3);
        compare(History.label(h[2], 20), "Image");
        compare(History.label(h[1], 20), "a.txt and 2 more");
        compare(History.label(h[0], 20), "a.txt");
        compare(History.thumbPath(h[2]), "/run/x/h1.png");
        compare(History.thumbPath(h[1]), "/x/pic.PNG");
        compare(History.thumbPath(h[0]), "");
    }

    function test_displayDirAndFileUrl() {
        compare(History.displayDir("/home/u/docs", "/home/u"), "~/docs");
        compare(History.displayDir("/home/u", "/home/u"), "~");
        compare(History.displayDir("/home/user2/x", "/home/u"), "/home/user2/x");
        compare(History.fileUrl("/a b/c#d.png"), "file:///a%20b/c%23d.png");
    }
}
