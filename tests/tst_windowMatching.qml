import QtQuick
import QtTest
import "../dock/windowMatching.js" as WindowMatching

TestCase {
    name: "WindowMatching"

    function appIds(windows) {
        return windows.map(w => w.appId);
    }

    function match(app, windowAppIds, wmClass) {
        let windows = windowAppIds.map(id => ({ "appId": id }));
        return appIds(WindowMatching.matchWindows(app, windows, wmClass || ""));
    }

    function test_noWindows() {
        compare(WindowMatching.matchWindows({ "id": "firefox" }, [], ""), []);
        compare(WindowMatching.matchWindows({ "id": "firefox" }, null, ""), []);
    }

    function test_skipsWindowsWithoutAppId() {
        let windows = [{ "appId": "" }, null, { "title": "no app id" }, { "appId": "firefox" }];
        compare(appIds(WindowMatching.matchWindows({ "id": "firefox" }, windows, "")), ["firefox"]);
    }

    function test_exactIdMatch() {
        compare(match({ "id": "org.kde.dolphin" }, ["org.kde.dolphin", "org.kde.konsole"]), ["org.kde.dolphin"]);
    }

    function test_ignoresCaseAndDesktopSuffix() {
        compare(match({ "id": "org.kde.Dolphin.desktop" }, ["org.kde.dolphin"]), ["org.kde.dolphin"]);
        compare(match({ "desktopFile": "org.kde.dolphin.desktop" }, ["ORG.KDE.DOLPHIN"]), ["ORG.KDE.DOLPHIN"]);
    }

    // Regression: the Vivaldi launcher entry used to match Vivaldi PWA windows
    // through substring matching, so launching Vivaldi focused the PWA.
    function test_strictWmClassExcludesPwaWindows() {
        let vivaldi = { "id": "vivaldi-stable", "desktopFile": "vivaldi-stable.desktop", "name": "Vivaldi", "command": "vivaldi" };
        let windows = ["vivaldi-stable", "vivaldi-ahiigpfcghkbjfcibpojancebdfjmoop-Default", "vivaldi"];
        compare(match(vivaldi, windows, "vivaldi-stable"), ["vivaldi-stable"]);
    }

    function test_strictMatchesWmClassWhenIdDiffers() {
        let app = { "id": "code", "desktopFile": "code.desktop" };
        compare(match(app, ["Code", "code-url-handler"], "Code"), ["Code"]);
    }

    function test_strictDisablesSubstringMatching() {
        let app = { "id": "steam", "name": "Steam", "command": "steam" };
        compare(match(app, ["steam_app_1245620", "steam"], "steam"), ["steam"]);
    }

    function test_rawAppIdExactMatch() {
        let game = { "id": "elden-ring", "rawAppId": "steam_app_1245620" };
        compare(match(game, ["steam_app_1245620", "steam_app_42"]), ["steam_app_1245620"]);
    }

    function test_reverseDnsSuffix() {
        compare(match({ "id": "firefox" }, ["org.mozilla.firefox"]), ["org.mozilla.firefox"]);
    }

    function test_desktopFileEndsWithWindowAppId() {
        compare(match({ "id": "org.gnome.Nautilus", "desktopFile": "org.gnome.Nautilus.desktop" }, ["nautilus"]), ["nautilus"]);
    }

    function test_commandMatch() {
        compare(match({ "id": "x", "command": "keepassxc" }, ["org.keepassxc.KeePassXC"]), ["org.keepassxc.KeePassXC"]);
    }

    function test_nameMatch() {
        compare(match({ "id": "x", "name": "Spotify" }, ["spotify-client"]), ["spotify-client"]);
    }

    function test_shortValuesDoNotSubstringMatch() {
        // Ids of 2 chars, commands of 2 chars and names of 3 chars are too
        // short to substring-match safely
        compare(match({ "id": "qt" }, ["qtcreator"]), []);
        compare(match({ "id": "x", "command": "vi" }, ["vivaldi"]), []);
        compare(match({ "id": "x", "name": "Vim" }, ["vimiv"]), []);
    }

    function test_unrelatedAppsDoNotMatch() {
        compare(match({ "id": "org.kde.konsole", "name": "Konsole", "command": "konsole" }, ["firefox", "org.kde.dolphin"]), []);
    }
}
