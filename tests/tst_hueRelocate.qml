import QtQuick
import QtTest
import "../services/hueRelocate.js" as HueRelocate

TestCase {
    name: "HueRelocate"

    function test_offlineSearchRetriesSoon() {
        compare(HueRelocate.waitAfter({ "error": "no route", "unreachable": true }), HueRelocate.OFFLINE_WAIT_MS);
    }

    function test_answeredSearchWaitsTheFullTime() {
        compare(HueRelocate.waitAfter({ "bridge": "10.0.0.2" }), HueRelocate.WAIT_MS);
        compare(HueRelocate.waitAfter({ "error": "bridge not found" }), HueRelocate.WAIT_MS);
        compare(HueRelocate.waitAfter({ "error": "bridge answered 429" }), HueRelocate.WAIT_MS);
    }

    function test_unreadableAnswerWaitsTheFullTime() {
        compare(HueRelocate.waitAfter(null), HueRelocate.WAIT_MS);
    }

    function test_countdownRoundsUp() {
        compare(HueRelocate.statusText("waiting", 14 * 60000 + 1), "Searching again in 15 min");
        compare(HueRelocate.statusText("waiting", 60000), "Searching again in 1 min");
        compare(HueRelocate.statusText("waiting", 59001), "Searching again in 60 s");
        compare(HueRelocate.statusText("waiting", 1), "Searching again in 1 s");
    }

    function test_otherStates() {
        compare(HueRelocate.statusText("searching", 0), "Looking for the bridge...");
        compare(HueRelocate.statusText("stopped", 0), "Automatic search stopped");
        compare(HueRelocate.statusText("", 0), "The bridge may have moved");
    }
}
