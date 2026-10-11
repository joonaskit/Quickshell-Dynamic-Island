"""Tests for the pure helpers in scripts/hue.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import hue  # noqa: E402


class NormalizeLightTest(unittest.TestCase):
    def test_full_colour_lamp(self):
        light = hue.normalize_light({
            "id": "abc",
            "metadata": {"name": "Desk"},
            "on": {"on": True},
            "dimming": {"brightness": 42.5},
            "color_temperature": {
                "mirek": 300,
                "mirek_schema": {"mirek_minimum": 153, "mirek_maximum": 500},
            },
        })
        self.assertEqual(light["id"], "abc")
        self.assertEqual(light["name"], "Desk")
        self.assertTrue(light["on"])
        self.assertTrue(light["hasBrightness"])
        self.assertEqual(light["brightness"], 42.5)
        self.assertTrue(light["hasColorTemp"])
        self.assertEqual(light["mirek"], 300)

    def test_on_off_plug_has_no_dimming_or_temperature(self):
        light = hue.normalize_light({"id": "p", "metadata": {"name": "Plug"}, "on": {"on": False}})
        self.assertFalse(light["on"])
        self.assertFalse(light["hasBrightness"])
        self.assertFalse(light["hasColorTemp"])

    def test_colour_mode_reports_no_mirek(self):
        light = hue.normalize_light({
            "id": "c",
            "color_temperature": {"mirek": None, "mirek_schema": {"mirek_minimum": 153, "mirek_maximum": 500}},
        })
        self.assertTrue(light["hasColorTemp"])
        self.assertEqual(light["mirek"], 0)


class BuildLightBodyTest(unittest.TestCase):
    def test_only_set_values_are_sent(self):
        self.assertEqual(hue.build_light_body(on=True), {"on": {"on": True}})
        self.assertEqual(hue.build_light_body(), {})

    def test_brightness_is_clamped_to_the_range_the_bridge_accepts(self):
        self.assertEqual(hue.build_light_body(brightness=0)["dimming"]["brightness"], 1.0)
        self.assertEqual(hue.build_light_body(brightness=250)["dimming"]["brightness"], 100.0)

    def test_mirek_is_an_integer(self):
        self.assertEqual(hue.build_light_body(mirek=300.0)["color_temperature"], {"mirek": 300})


class ParsePairResponseTest(unittest.TestCase):
    def test_success_returns_the_key(self):
        self.assertEqual(hue.parse_pair_response([{"success": {"username": "k"}}]), ("k", None))

    def test_link_button_not_pressed(self):
        self.assertEqual(hue.parse_pair_response([{"error": {"type": 101}}]), (None, "link_button"))

    def test_other_error_keeps_the_description(self):
        data = [{"error": {"type": 7, "description": "bad"}}]
        self.assertEqual(hue.parse_pair_response(data), (None, "bad"))

    def test_garbage(self):
        self.assertEqual(hue.parse_pair_response({})[0], None)


if __name__ == "__main__":
    unittest.main()
