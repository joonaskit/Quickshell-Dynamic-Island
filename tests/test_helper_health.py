"""Tests for scripts/helper_health.py. Run with ./test.sh."""
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import helper_health as hh  # noqa: E402

DIR = "/home/u/shell"
SCRIPTS = DIR + "/scripts"


def cmdline(*parts):
    return "\0".join(parts) + "\0"


class ParseCmdlineTest(unittest.TestCase):
    def test_python_script(self):
        raw = cmdline("python3", "-u", SCRIPTS + "/clipboard_tracker.py")
        self.assertEqual(hh.parse_cmdline(raw, SCRIPTS), ("clipboard_tracker.py", []))

    def test_arguments_after_the_script(self):
        raw = cmdline("python3", "-u", SCRIPTS + "/devices.py", "monitor")
        self.assertEqual(hh.parse_cmdline(raw, SCRIPTS), ("devices.py", ["monitor"]))

    def test_other_install_is_ignored(self):
        raw = cmdline("python3", "/opt/other/scripts/hardware_stats.py")
        self.assertIsNone(hh.parse_cmdline(raw, SCRIPTS))

    def test_not_a_python_file(self):
        self.assertIsNone(hh.parse_cmdline(cmdline("vim", SCRIPTS + "/kwin_script.js"), SCRIPTS))

    def test_nested_path_is_ignored(self):
        self.assertIsNone(hh.parse_cmdline(cmdline("python3", SCRIPTS + "/sub/x.py"), SCRIPTS))

    def test_script_name_only_as_an_argument_of_another_program(self):
        raw = cmdline("tail", "-f", "log", "x" + SCRIPTS + "/hardware_stats.py")
        self.assertIsNone(hh.parse_cmdline(raw, SCRIPTS))


class LongRunningTest(unittest.TestCase):
    def test_devices_monitor_only(self):
        self.assertTrue(hh.is_long_running("devices.py", ["monitor"]))
        self.assertFalse(hh.is_long_running("devices.py", ["list"]))

    def test_one_shot_scripts(self):
        self.assertFalse(hh.is_long_running("shortcuts.py", []))
        self.assertFalse(hh.is_long_running("island_run.py", []))

    def test_tracker(self):
        self.assertTrue(hh.is_long_running("kwin_window_tracker.py", []))


class FindHelpersTest(unittest.TestCase):
    def test_reads_proc(self):
        with tempfile.TemporaryDirectory() as root:
            for pid, raw in {
                "10": cmdline("python3", SCRIPTS + "/hardware_stats.py"),
                "11": cmdline("python3", SCRIPTS + "/hardware_stats.py"),
                "12": cmdline("python3", SCRIPTS + "/audio_sinks.py", "list"),
                "13": cmdline("bash"),
            }.items():
                os.makedirs(os.path.join(root, pid))
                with open(os.path.join(root, pid, "cmdline"), "w") as f:
                    f.write(raw)
            os.makedirs(os.path.join(root, "self"))
            found = hh.find_helpers(DIR, proc_root=root)
        self.assertEqual(found, [{"pid": 10, "script": "hardware_stats.py"}, {"pid": 11, "script": "hardware_stats.py"}])

    def test_unreadable_proc(self):
        self.assertEqual(hh.find_helpers(DIR, proc_root="/nonexistent"), [])


class StaleTest(unittest.TestCase):
    helpers = [{"pid": 1, "script": "a.py"}, {"pid": 2, "script": "a.py"}]

    def test_unowned_is_stale(self):
        marked = hh.mark_stale(self.helpers, [2])
        self.assertEqual([h["stale"] for h in marked], [True, False])

    def test_nothing_owned_marks_all(self):
        self.assertTrue(all(h["stale"] for h in hh.mark_stale(self.helpers, [])))

    def test_kill_only_stale(self):
        marked = hh.mark_stale(self.helpers, [2])
        with mock.patch("os.kill") as kill:
            self.assertEqual(hh.kill_stale(marked), [1])
        kill.assert_called_once_with(1, hh.signal.SIGTERM)

    def test_kill_survives_a_vanished_process(self):
        marked = hh.mark_stale(self.helpers, [])
        with mock.patch("os.kill", side_effect=ProcessLookupError):
            self.assertEqual(hh.kill_stale(marked), [])


if __name__ == "__main__":
    unittest.main()
