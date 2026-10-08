"""Tests for scripts/write_theme.py. Run with ./test.sh."""
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import write_theme  # noqa: E402


class ThemePathTest(unittest.TestCase):
    def test_uses_xdg_config_home(self):
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": "/tmp/xdg"}):
            self.assertEqual(write_theme.theme_path(), "/tmp/xdg/quickshell-island/theme.json")

    def test_falls_back_to_dot_config(self):
        env = {k: v for k, v in os.environ.items() if k != "XDG_CONFIG_HOME"}
        env["HOME"] = "/home/someone"
        with mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(write_theme.theme_path(), "/home/someone/.config/quickshell-island/theme.json")

    def test_empty_xdg_config_home_falls_back(self):
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": "", "HOME": "/home/someone"}):
            self.assertEqual(write_theme.theme_path(), "/home/someone/.config/quickshell-island/theme.json")


class WriteThemeTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.path = os.path.join(self.dir.name, "quickshell-island", "theme.json")

    def read(self):
        with open(self.path, encoding="utf-8") as f:
            return f.read()

    def test_creates_directory_and_file(self):
        self.assertTrue(write_theme.write_theme('{"version": 1}\n', self.path))
        self.assertEqual(self.read(), '{"version": 1}\n')

    def test_replaces_changed_content(self):
        write_theme.write_theme("old\n", self.path)
        self.assertTrue(write_theme.write_theme("new\n", self.path))
        self.assertEqual(self.read(), "new\n")

    def test_unchanged_content_is_not_rewritten(self):
        write_theme.write_theme("same\n", self.path)
        os.utime(self.path, (1000, 1000))
        self.assertFalse(write_theme.write_theme("same\n", self.path))
        self.assertEqual(os.path.getmtime(self.path), 1000)

    def test_leaves_no_temp_files(self):
        write_theme.write_theme("a\n", self.path)
        write_theme.write_theme("b\n", self.path)
        self.assertEqual(os.listdir(os.path.dirname(self.path)), ["theme.json"])


class MainTest(unittest.TestCase):
    def run_main(self, args, config_home):
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": config_home}), \
                mock.patch.object(sys, "argv", ["write_theme.py", *args]), \
                mock.patch.object(sys, "stderr"):
            return write_theme.main()

    def test_writes_indented_json(self):
        with tempfile.TemporaryDirectory() as config_home:
            self.assertEqual(self.run_main(['{"version":1}'], config_home), 0)
            with open(os.path.join(config_home, "quickshell-island", "theme.json"), encoding="utf-8") as f:
                self.assertEqual(f.read(), '{\n  "version": 1\n}\n')

    def test_malformed_json_writes_nothing(self):
        with tempfile.TemporaryDirectory() as config_home:
            with self.assertRaises(ValueError):
                self.run_main(["{not json"], config_home)
            self.assertEqual(os.listdir(config_home), [])

    def test_wrong_argument_count(self):
        with tempfile.TemporaryDirectory() as config_home:
            self.assertEqual(self.run_main([], config_home), 2)
            self.assertEqual(os.listdir(config_home), [])


if __name__ == "__main__":
    unittest.main()
