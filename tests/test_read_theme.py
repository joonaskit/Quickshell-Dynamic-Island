"""Tests for examples/read_theme.py. Run with ./test.sh."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "examples"))

import read_theme  # noqa: E402


class LoadThemeTest(unittest.TestCase):
    def load(self, content):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "theme.json")
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            return read_theme.load_theme(path)

    def test_missing_file_gives_defaults(self):
        self.assertEqual(read_theme.load_theme("/nonexistent/theme.json"), read_theme.DEFAULTS)

    def test_malformed_file_gives_defaults(self):
        self.assertEqual(self.load("{not json"), read_theme.DEFAULTS)
        self.assertEqual(self.load("[1, 2]"), read_theme.DEFAULTS)

    def test_file_values_override_defaults(self):
        theme = self.load(json.dumps({"version": 1, "colors": {"accent": "#123456"}, "scale": {"ui": 1.25}}))
        self.assertEqual(theme["colors"]["accent"], "#123456")
        self.assertEqual(theme["scale"]["ui"], 1.25)

    def test_missing_fields_keep_defaults(self):
        theme = self.load(json.dumps({"version": 1, "colors": {"accent": "#123456"}}))
        self.assertEqual(theme["colors"]["surface"], read_theme.DEFAULTS["colors"]["surface"])
        self.assertEqual(theme["scale"], read_theme.DEFAULTS["scale"])
        self.assertEqual(theme["radius"], read_theme.DEFAULTS["radius"])

    def test_unknown_fields_are_kept(self):
        theme = self.load(json.dumps({"version": 1, "colors": {"brandNew": "#abcdef"}, "extra": 1}))
        self.assertEqual(theme["colors"]["brandNew"], "#abcdef")
        self.assertEqual(theme["extra"], 1)

    def test_newer_version_gives_defaults(self):
        self.assertEqual(self.load(json.dumps({"version": 2, "colors": {"accent": "#123456"}})), read_theme.DEFAULTS)

    def test_missing_version_gives_defaults(self):
        self.assertEqual(self.load(json.dumps({"colors": {"accent": "#123456"}})), read_theme.DEFAULTS)

    def test_wrongly_shaped_section_is_ignored(self):
        theme = self.load(json.dumps({"version": 1, "colors": "blue", "scale": {"ui": 1.1}}))
        self.assertEqual(theme["colors"], read_theme.DEFAULTS["colors"])
        self.assertEqual(theme["scale"]["ui"], 1.1)

    def test_defaults_are_not_mutated(self):
        before = json.dumps(read_theme.DEFAULTS, sort_keys=True)
        theme = self.load(json.dumps({"version": 1, "colors": {"accent": "#123456"}}))
        theme["colors"]["surface"] = "changed"
        theme["scale"]["ui"] = 9
        read_theme.load_theme("/nonexistent/theme.json")["radius"]["small"] = 99
        self.assertEqual(json.dumps(read_theme.DEFAULTS, sort_keys=True), before)


class ScalingTest(unittest.TestCase):
    def test_scaling_matches_the_shell(self):
        theme = read_theme.merge(read_theme.DEFAULTS, {"scale": {"ui": 1.05, "font": 1.1}})
        self.assertEqual(read_theme.scaled(theme, 40), 42)
        self.assertEqual(read_theme.font_scaled(theme, 12), 14)

    def test_font_size_has_a_minimum(self):
        theme = read_theme.merge(read_theme.DEFAULTS, {"scale": {"ui": 0.8, "font": 0.85}})
        self.assertEqual(read_theme.font_scaled(theme, 8), 8)


if __name__ == "__main__":
    unittest.main()
