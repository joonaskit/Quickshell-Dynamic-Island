import QtQuick
import QtTest
import "../services/animationSpeed.js" as AnimationSpeed

TestCase {
    name: "AnimationSpeed"

    function test_kdeDefaultWhenAbsent() {
        compare(AnimationSpeed.kdeFactor(""), 1);
        compare(AnimationSpeed.kdeFactor("[KDE]\nLookAndFeelPackage=org.kde.breezedark.desktop\n"), 1);
    }

    function test_kdeInstant() {
        compare(AnimationSpeed.kdeFactor("[General]\nfoo=1\n\n[KDE]\nAnimationDurationFactor=0\n"), 0);
    }

    function test_kdeSlower() {
        compare(AnimationSpeed.kdeFactor("[KDE]\nAnimationDurationFactor=2.5\nSingleClick=false\n"), 2.5);
    }

    function test_kdeOnlyItsGroup() {
        compare(AnimationSpeed.kdeFactor("[Other]\nAnimationDurationFactor=0\n[KDE]\nSingleClick=false\n"), 1);
    }

    function test_kdeBadValue() {
        compare(AnimationSpeed.kdeFactor("[KDE]\nAnimationDurationFactor=fast\n"), 1);
        compare(AnimationSpeed.kdeFactor("[KDE]\nAnimationDurationFactor=-1\n"), 1);
    }

    function test_niriDefault() {
        compare(AnimationSpeed.niriFactor(""), 1);
        compare(AnimationSpeed.niriFactor("input {\n    keyboard { }\n}\n"), 1);
    }

    function test_niriCommentedOut() {
        let text = "animations {\n    // Uncomment to turn off all animations.\n    // off\n\n    // slowdown 3.0\n}\n";
        compare(AnimationSpeed.niriFactor(text), 1);
    }

    function test_niriOff() {
        compare(AnimationSpeed.niriFactor("animations {\n    off\n}\n"), 0);
        compare(AnimationSpeed.niriFactor("animations { off; }"), 0);
        compare(AnimationSpeed.niriFactor("animations { off }"), 0);
    }

    function test_niriSlowdown() {
        compare(AnimationSpeed.niriFactor("animations {\n    slowdown 3.0\n}\n"), 3);
        compare(AnimationSpeed.niriFactor("animations {\n    slowdown 0.5\n}\n"), 0.5);
    }

    function test_niriSkipsInnerBlocks() {
        let text = "animations {\n    window-open {\n        off\n        duration-ms 150\n    }\n    slowdown 2\n}\n";
        compare(AnimationSpeed.niriFactor(text), 2);
    }

    function test_niriSlashdash() {
        compare(AnimationSpeed.niriFactor("animations {\n    /-off\n}\n"), 1);
        compare(AnimationSpeed.niriFactor("/-animations {\n    off\n}\n"), 1);
    }

    function test_niriBlockComment() {
        compare(AnimationSpeed.niriFactor("animations {\n    /* off */\n    slowdown 2\n}\n"), 2);
    }

    function test_niriOtherBlockNamedLikeIt() {
        compare(AnimationSpeed.niriFactor("window-animations {\n    off\n}\n"), 1);
    }

    function test_scale() {
        compare(AnimationSpeed.scale(360, 1), 360);
        compare(AnimationSpeed.scale(360, 0), 0);
        compare(AnimationSpeed.scale(180, 0.5), 90);
        compare(AnimationSpeed.scale(120, 1.25), 150);
    }
}
