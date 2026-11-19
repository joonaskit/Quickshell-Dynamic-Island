"""Tests for scripts/niri_blur_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import niri_blur_core as core  # noqa: E402

ALL = core.NAMESPACES


class AnalyzeTest(unittest.TestCase):
    def test_blur_is_on_by_request_with_no_config(self):
        r = core.analyze([""])
        self.assertTrue(r["enabled"])
        self.assertEqual(r["blurred"], ALL)
        self.assertEqual(r["blockedBy"], [])
        self.assertEqual(r["xrayOff"], [])

    def test_blur_off(self):
        r = core.analyze(["blur {\n    off\n    passes 3\n}\n"])
        self.assertFalse(r["enabled"])
        self.assertEqual(r["blurred"], [])

    def test_blur_block_without_off(self):
        self.assertTrue(core.analyze(["blur {\n    // off\n    passes 4\n}\n"])["enabled"])
        self.assertTrue(core.analyze(["/-blur { off; }\n"])["enabled"])

    def test_a_rule_turning_blur_off(self):
        text = 'layer-rule {\n    match namespace="^quickshell-dock$"\n    background-effect { blur false; }\n}\n'
        r = core.analyze([text])
        self.assertEqual(r["blockedBy"], ["quickshell-dock"])
        self.assertNotIn("quickshell-dock", r["blurred"])
        self.assertIn("quickshell-island", r["blurred"])

    def test_later_rules_win(self):
        text = ('layer-rule { match namespace="^quickshell"; background-effect { blur false; }; }\n'
                'layer-rule { match namespace="island"; background-effect { blur true; }; }\n')
        r = core.analyze([text])
        self.assertEqual(r["blurred"], ["quickshell-island"])

    def test_kdl_v2_booleans(self):
        text = 'layer-rule { match namespace="^quickshell"; background-effect { blur #false; xray #false; }; }\n'
        r = core.analyze([text])
        self.assertEqual(r["blockedBy"], ALL)
        self.assertEqual(r["xrayOff"], ALL)

    def test_xray_off(self):
        text = 'layer-rule {\n    match namespace="^quickshell"\n\n    background-effect {\n        xray false\n    }\n}\n'
        r = core.analyze([text])
        self.assertEqual(r["xrayOff"], ALL)
        self.assertEqual(r["blurred"], ALL)

    def test_match_and_exclude(self):
        text = ('layer-rule {\n    match layer="top"\n    exclude namespace="dock"\n'
                '    background-effect { blur false; }\n}\n')
        r = core.analyze([text])
        self.assertEqual(r["blurred"], ["quickshell-dock"])
        # A layer the shell's surfaces are not on
        r = core.analyze(['layer-rule { match layer="bottom"; background-effect { blur false; }; }\n'])
        self.assertEqual(r["blockedBy"], [])

    def test_unknown_matchers_do_not_hold(self):
        r = core.analyze(['layer-rule { match at-startup=true; background-effect { blur false; }; }\n'])
        self.assertEqual(r["blockedBy"], [])

    def test_skipped_rules_and_bad_regex(self):
        r = core.analyze(['/-layer-rule { match namespace="^quickshell"; background-effect { blur false; }; }\n'
                          'layer-rule { match namespace="(["; background-effect { blur false; }; }\n'])
        self.assertEqual(r["blockedBy"], [])

    def test_included_files_are_read_in_order(self):
        r = core.analyze(["blur { off; }\n", "blur { passes 2; }\n"])
        self.assertTrue(r["enabled"])

    def test_suggested_rule_parses_and_turns_xray_off(self):
        self.assertEqual(core.analyze([core.SUGGESTED_RULE])["xrayOff"], ALL)


class IncludesTest(unittest.TestCase):
    def test_includes(self):
        text = 'include "a.kdl"\n/-include "b.kdl"\ninclude optional=true "c.kdl"\n'
        self.assertEqual(core.includes(text), ["a.kdl", "c.kdl"])


if __name__ == "__main__":
    unittest.main()
