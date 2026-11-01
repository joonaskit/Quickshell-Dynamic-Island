import QtQuick
import QtTest
import "../components/colorMath.js" as ColorMath

TestCase {
    name: "ColorMath"

    function compareColor(actual, r, g, b, a) {
        fuzzyCompare(actual.r, r, 0.001);
        fuzzyCompare(actual.g, g, 0.001);
        fuzzyCompare(actual.b, b, 0.001);
        fuzzyCompare(actual.a, a, 0.001);
    }

    function test_opaqueTopHidesBottom() {
        compareColor(ColorMath.over(Qt.rgba(1, 0, 0, 1), Qt.rgba(0, 0, 1, 1)), 1, 0, 0, 1);
    }

    function test_clearTopLeavesBottom() {
        compareColor(ColorMath.over(Qt.rgba(1, 0, 0, 0), Qt.rgba(0, 0, 1, 0.5)), 0, 0, 1, 0.5);
    }

    function test_translucentTopOverOpaque() {
        compareColor(ColorMath.over(Qt.rgba(1, 1, 1, 0.5), Qt.rgba(0, 0, 0, 1)), 0.5, 0.5, 0.5, 1);
    }

    function test_bothTranslucent() {
        compareColor(ColorMath.over(Qt.rgba(1, 0, 0, 0.5), Qt.rgba(0, 0, 1, 0.5)), 2 / 3, 0, 1 / 3, 0.75);
    }

    function test_bothClearIsClear() {
        compareColor(ColorMath.over(Qt.rgba(1, 1, 1, 0), Qt.rgba(1, 1, 1, 0)), 0, 0, 0, 0);
    }
}
