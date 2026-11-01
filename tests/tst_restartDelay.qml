import QtQuick
import QtTest
import "../services/restartDelay.js" as RestartDelay

TestCase {
    name: "RestartDelay"

    function test_quickExitCounts() {
        compare(RestartDelay.countQuickExits(0, 100), 1);
        compare(RestartDelay.countQuickExits(3, 4999), 4);
    }

    function test_longRunResetsTheCount() {
        compare(RestartDelay.countQuickExits(3, 5000), 0);
        compare(RestartDelay.countQuickExits(0, 60000), 0);
    }

    function test_noQuickExitsIsTheBaseDelay() {
        compare(RestartDelay.delay(2000, 0), 2000);
    }

    function test_doublesForEachQuickExit() {
        compare(RestartDelay.delay(1000, 1), 2000);
        compare(RestartDelay.delay(1000, 3), 8000);
    }

    function test_stopsAtTheCap() {
        compare(RestartDelay.delay(1000, 5), 30000);
        compare(RestartDelay.delay(1000, 50), 30000);
        compare(RestartDelay.delay(5000, 3), 30000);
    }
}
