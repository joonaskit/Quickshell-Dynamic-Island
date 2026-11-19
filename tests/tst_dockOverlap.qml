import QtQuick
import QtTest
import "../dock/dockOverlap.js" as DockOverlap

TestCase {
    name: "DockOverlap"

    readonly property var screenBox: ({ "name": "DP-1", "x": 0, "y": 0, "width": 2560, "height": 1440 })
    readonly property var bottomDock: DockOverlap.dockRect(screenBox, "bottom", 600, 80)

    function test_dockRect() {
        compare(bottomDock, { "left": 980, "right": 1580, "top": 1360, "bottom": 1440 });
        compare(DockOverlap.dockRect(screenBox, "left", 600, 80), { "left": 0, "right": 80, "top": 420, "bottom": 1020 });
        compare(DockOverlap.dockRect(screenBox, "right", 600, 80), { "left": 2480, "right": 2560, "top": 420, "bottom": 1020 });
        let second = { "x": 2560, "y": 0, "width": 1920, "height": 1080 };
        compare(DockOverlap.dockRect(second, "bottom", 600, 80).left, 2560 + 660);
    }

    function test_noWindows() {
        verify(!DockOverlap.overlaps([], screenBox, bottomDock));
        verify(!DockOverlap.overlaps(null, screenBox, bottomDock));
    }

    function test_windowAboveTheDockDoesNotCount() {
        verify(!DockOverlap.overlaps([{ "app": "foot", "x": 1000, "y": 100, "width": 500, "height": 500 }], screenBox, bottomDock));
    }

    function test_windowReachingTheDockCounts() {
        verify(DockOverlap.overlaps([{ "app": "foot", "x": 1000, "y": 1000, "width": 500, "height": 400 }], screenBox, bottomDock));
    }

    function test_maximizedCounts() {
        verify(DockOverlap.overlaps([{ "app": "foot", "maximized": true }], screenBox, bottomDock));
    }

    function test_niriTiledWindowsCount() {
        verify(DockOverlap.overlaps([{ "app": "foot", "spansHeight": true, "screen": "DP-1" }], screenBox, bottomDock));
    }

    function test_skipped() {
        let covering = { "x": 0, "y": 0, "width": 2560, "height": 1440 };
        let cases = [
            Object.assign({ "app": "foot", "minimized": true }, covering),
            Object.assign({ "app": "foot", "onCurrent": false }, covering),
            Object.assign({ "app": "foot", "screen": "HDMI-A-1" }, covering),
            Object.assign({ "app": "quickshell" }, covering),
            Object.assign({ "app": "org.kde.plasmashell" }, covering),
            { "app": "foot", "spansHeight": true, "screen": "HDMI-A-1" },
            { "app": "foot", "x": 1000, "y": 1000, "width": 0, "height": 0 }
        ];
        for (let i = 0; i < cases.length; i++) verify(!DockOverlap.overlaps([cases[i]], screenBox, bottomDock), "case " + i);
    }

    function test_screenRelativePositionsOnASecondScreen() {
        let second = { "name": "HDMI-A-1", "x": 2560, "y": 0, "width": 1920, "height": 1080 };
        let rect = DockOverlap.dockRect(second, "bottom", 600, 80);
        // A floating niri window near the bottom middle of the second screen, in its own coordinates
        verify(DockOverlap.overlaps([{ "app": "foot", "x": 800, "y": 900, "width": 300, "height": 150, "screen": "HDMI-A-1" }], second, rect));
        verify(!DockOverlap.overlaps([{ "app": "foot", "x": 800, "y": 100, "width": 300, "height": 150, "screen": "HDMI-A-1" }], second, rect));
    }
}
