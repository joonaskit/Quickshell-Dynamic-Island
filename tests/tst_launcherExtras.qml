import QtQuick
import QtTest
import "../services/launcherExtras.js" as Extras

TestCase {
    name: "LauncherExtras"

    function test_arithmetic() {
        compare(Extras.evaluate("2*(3+4)"), 14);
        compare(Extras.evaluate("2+3*4"), 14);
        compare(Extras.evaluate("10/4"), 2.5);
        compare(Extras.evaluate("10 % 4"), 2);
        compare(Extras.evaluate("2^3^2"), 512);
        compare(Extras.evaluate("2**10"), 1024);
        compare(Extras.evaluate("-3 + 5"), 2);
        compare(Extras.evaluate("2 * -3"), -6);
        compare(Extras.evaluate("1,5 * 2"), 3);
        compare(Extras.evaluate("6 × 7"), 42);
        compare(Extras.evaluate("9 ÷ 3"), 3);
    }

    function test_functionsAndConstants() {
        compare(Extras.evaluate("sqrt(16)"), 4);
        compare(Extras.evaluate("SQRT(16) + 1"), 5);
        fuzzyCompare(Extras.evaluate("2*pi"), 6.283185307, 1e-8);
        compare(Extras.evaluate("log(1000)"), 3);
    }

    function test_notAnAnswer() {
        compare(Extras.evaluate("5"), null);
        compare(Extras.evaluate("-5"), null);
        compare(Extras.evaluate("(5)"), null);
        compare(Extras.evaluate("pi"), null);
        compare(Extras.evaluate("firefox"), null);
        compare(Extras.evaluate("2 firefox"), null);
        compare(Extras.evaluate(""), null);
    }

    function test_invalid() {
        compare(Extras.evaluate("1/0"), null);
        compare(Extras.evaluate("2+"), null);
        compare(Extras.evaluate("(2+3"), null);
        compare(Extras.evaluate("2+3)"), null);
        compare(Extras.evaluate("foo(2)"), null);
        compare(Extras.evaluate("sqrt(-1)"), null);
        compare(Extras.evaluate("10^400"), null);
        compare(Extras.evaluate("2 + alert(1)"), null);
    }

    function test_noCodeIsRun() {
        compare(Extras.evaluate("constructor"), null);
        compare(Extras.evaluate("__proto__ + 1"), null);
        compare(Extras.evaluate("toString(1)"), null);
        compare(Extras.evaluate("1; 2"), null);
    }

    function test_overlongQuery() {
        compare(Extras.evaluate("1+".repeat(200) + "1"), null);
    }

    function test_formatNumber() {
        compare(Extras.formatNumber(14), "14");
        compare(Extras.formatNumber(0.1 + 0.2), "0.3");
        compare(Extras.formatNumber(1 / 3), "0.3333333333");
        compare(Extras.formatNumber(1e20), "1e+20");
        compare(Extras.formatNumber(-2.50), "-2.5");
        compare(Extras.formatNumber(0), "0");
    }

    function test_convertLength() {
        let r = Extras.convert("5 km in mi");
        verify(r !== null);
        fuzzyCompare(r.value, 3.106855961, 1e-8);
        compare(r.text, "5 km = 3.106855961 mi");
        compare(r.copy, "3.106855961");
    }

    function test_convertWordsAndCase() {
        compare(Extras.convert("1 Mile to Kilometers").copy, "1.609344");
        compare(Extras.convert("12 inches as cm").copy, "30.48");
    }

    function test_inchIsNotTheConnector() {
        compare(Extras.convert("5 in in cm").copy, "12.7");
    }

    function test_convertTemperature() {
        compare(Extras.convert("100 c to f").copy, "212");
        compare(Extras.convert("32 F in C").copy, "0");
        compare(Extras.convert("0 c in k").copy, "273.15");
    }

    function test_convertOthers() {
        compare(Extras.convert("1 gib in mib").copy, "1024");
        compare(Extras.convert("1 h in min").copy, "60");
        compare(Extras.convert("100 km/h in mph").copy, "62.13711923");
        compare(Extras.convert("1 l in ml").copy, "1000");
    }

    function test_convertRefusesMixedOrUnknown() {
        compare(Extras.convert("5 km in kg"), null);
        compare(Extras.convert("5 foo in bar"), null);
        compare(Extras.convert("km in mi"), null);
        compare(Extras.convert("5 km mi"), null);
    }

    readonly property var shortcuts: [
        { key: "g", name: "Google", url: "https://www.google.com/search?q=%s" },
        { key: "bad", name: "Bad", url: "javascript:alert(1)" },
        { key: "x", name: "NoPlaceholder", url: "https://example.com/?q=" }
    ]

    function test_webSearch() {
        let r = Extras.webSearch("g hello world & more", shortcuts);
        compare(r.name, "Google");
        compare(r.url, "https://www.google.com/search?q=hello%20world%20%26%20more");
        compare(r.term, "hello world & more");
    }

    function test_webSearchKeyIsCaseInsensitive() {
        compare(Extras.webSearch("G cats", shortcuts).url, "https://www.google.com/search?q=cats");
    }

    function test_webSearchNeedsATerm() {
        compare(Extras.webSearch("g", shortcuts), null);
        compare(Extras.webSearch("g   ", shortcuts), null);
        compare(Extras.webSearch("firefox browser", shortcuts), null);
    }

    function test_webSearchAppendsWithoutPlaceholder() {
        compare(Extras.webSearch("x a b", shortcuts).url, "https://example.com/?q=a%20b");
    }

    function test_webSearchRefusesOtherSchemes() {
        compare(Extras.webSearch("bad hello", shortcuts), null);
    }

    function test_parseShortcuts() {
        let list = Extras.parseShortcuts("G | Google | https://www.google.com/search?q=%s\n\nnonsense\nbad | Bad | file:///etc/passwd\ng | Dup | https://dup.example/?q=%s\nw||https://en.wikipedia.org/?s=%s");
        compare(list.length, 2);
        compare(list[0].key, "g");
        compare(list[0].name, "Google");
        compare(list[1].key, "w");
        compare(list[1].name, "w");
    }

    function test_shortcutsRoundTrip() {
        let text = Extras.formatShortcuts(Extras.DEFAULT_SHORTCUTS);
        compare(Extras.parseShortcuts(text), Extras.DEFAULT_SHORTCUTS);
    }

    readonly property var all: ({ calculator: true, conversion: true, web: true, shortcuts: Extras.DEFAULT_SHORTCUTS })

    function test_answerKinds() {
        compare(Extras.answer("2*(3+4)", all).kind, "calc");
        compare(Extras.answer("2*(3+4)", all).copy, "14");
        compare(Extras.answer("5 km in mi", all).kind, "convert");
        compare(Extras.answer("g cats", all).kind, "web");
        compare(Extras.answer("firefox", all), null);
        compare(Extras.answer("   ", all), null);
    }

    function test_answerHonoursSwitches() {
        compare(Extras.answer("2+2", { calculator: false, conversion: true, web: true, shortcuts: Extras.DEFAULT_SHORTCUTS }), null);
        compare(Extras.answer("5 km in mi", { calculator: true, conversion: false, web: true, shortcuts: Extras.DEFAULT_SHORTCUTS }), null);
        compare(Extras.answer("g cats", { calculator: true, conversion: true, web: false, shortcuts: Extras.DEFAULT_SHORTCUTS }), null);
    }

    function test_fileQuery() {
        compare(Extras.fileQuery("f report 2024", "f"), "report 2024");
        compare(Extras.fileQuery("  F  report ", "f"), "report");
        compare(Extras.fileQuery("f ", "f"), "");
        compare(Extras.fileQuery("f", "f"), null);
        compare(Extras.fileQuery("firefox", "f"), null);
        compare(Extras.fileQuery("find report", "f"), null);
        compare(Extras.fileQuery("file report", "file"), "report");
        compare(Extras.fileQuery("f report", ""), null);
    }

    function test_parseFileLine() {
        let r = Extras.parseFileLine('{"path": "/home/me/docs/a b.pdf", "name": "a b.pdf", "folder": "/home/me/docs", "dir": false, "type": "application/pdf"}');
        compare(r.path, "/home/me/docs/a b.pdf");
        compare(r.name, "a b.pdf");
        compare(r.folder, "/home/me/docs");
        compare(r.dir, false);
        compare(r.type, "application/pdf");
    }

    function test_parseFileLineEndAndError() {
        compare(Extras.parseFileLine('{"done": true, "more": true}'), { done: true, more: true });
        compare(Extras.parseFileLine('{"error": "Not a folder: /x"}'), { error: "Not a folder: /x" });
    }

    function test_parseFileLineFillsWhatIsMissing() {
        let r = Extras.parseFileLine('{"path": "/a/b/c.txt", "extra": 1}');
        compare(r.name, "c.txt");
        compare(r.folder, "");
        compare(r.type, "");
    }

    function test_parseFileLineRefusesOtherOutput() {
        compare(Extras.parseFileLine("Traceback (most recent call last):"), null);
        compare(Extras.parseFileLine("[1, 2]"), null);
        compare(Extras.parseFileLine('{"name": "no path"}'), null);
        compare(Extras.parseFileLine("null"), null);
    }

    function test_shortFolder() {
        compare(Extras.shortFolder("/home/me/docs", "/home/me"), "~/docs");
        compare(Extras.shortFolder("/home/me", "/home/me"), "~");
        compare(Extras.shortFolder("/home/meta/docs", "/home/me"), "/home/meta/docs");
        compare(Extras.shortFolder("/etc", "/home/me"), "/etc");
        compare(Extras.shortFolder("/etc", ""), "/etc");
    }

    function test_fileUrl() {
        compare(Extras.fileUrl("/home/me/a b#1?.pdf"), "file:///home/me/a%20b%231%3F.pdf");
    }

    function test_fileIconName() {
        compare(Extras.fileIconName({ dir: true, type: "inode/directory" }), "folder");
        compare(Extras.fileIconName({ dir: false, type: "application/pdf" }), "application-pdf");
        compare(Extras.fileIconName({ dir: false, type: "" }), "text-x-generic");
    }

    readonly property var pages: [
        { name: "Wi-Fi & Internet", comment: "Network connections", keywords: ["wifi", "network"] },
        { name: "Display Configuration", comment: "Resolution and scale", keywords: ["monitor", "screen"] },
        { name: "Night Light", comment: "Warmer colours in the evening", keywords: [] },
        { name: "Colors", comment: "Choose the colour scheme", keywords: ["theme"] },
        { name: "Notifications", comment: "", keywords: [] }
    ]

    function names(list) { return list.map(function(p) { return p.name; }); }

    function test_settingsPagesRankByWhereTheyMatch() {
        // name start, then inside the name, then keyword, then description
        compare(names(Extras.matchSettingsPages(pages, "n", 8)), ["Night Light", "Notifications", "Display Configuration", "Wi-Fi & Internet"]);
        compare(names(Extras.matchSettingsPages(pages, "light", 8)), ["Night Light"]);
        compare(names(Extras.matchSettingsPages(pages, "monitor", 8)), ["Display Configuration"]);
        compare(names(Extras.matchSettingsPages(pages, "evening", 8)), ["Night Light"]);
    }

    function test_settingsPagesNeedEveryWord() {
        compare(names(Extras.matchSettingsPages(pages, "colour scheme", 8)), ["Colors"]);
        compare(names(Extras.matchSettingsPages(pages, "night scheme", 8)), []);
        compare(names(Extras.matchSettingsPages(pages, "  DISPLAY  ", 8)), ["Display Configuration"]);
    }

    function test_settingsPagesLimitAndEmpty() {
        compare(Extras.matchSettingsPages(pages, "n", 2).length, 2);
        compare(Extras.matchSettingsPages(pages, "", 8).length, 0);
        compare(Extras.matchSettingsPages(pages, "   ", 8).length, 0);
        compare(Extras.matchSettingsPages(null, "n", 8).length, 0);
        compare(Extras.matchSettingsPages(pages, "n".repeat(300), 8).length, 0);
    }
}
