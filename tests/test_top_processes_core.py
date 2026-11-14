"""Tests for scripts/top_processes_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import top_processes_core as core  # noqa: E402


def stat_line(pid, name, utime, stime, rss):
    # pid (name) state ppid pgrp session tty tpgid flags minflt cminflt majflt cmajflt
    # utime stime cutime cstime priority nice threads itrealvalue starttime vsize rss ...
    return "%d (%s) S 1 1 1 0 -1 0 0 0 0 0 %d %d 0 0 20 0 1 0 100 1000 %d 0 0" % (pid, name, utime, stime, rss)


class ParseStat(unittest.TestCase):
    def test_reads_name_ticks_and_rss(self):
        self.assertEqual(core.parse_stat(stat_line(7, "firefox", 30, 12, 500)), ("firefox", 42, 500))

    def test_name_with_spaces_and_parentheses(self):
        self.assertEqual(core.parse_stat(stat_line(7, "Web (Content)", 1, 2, 3)), ("Web (Content)", 3, 3))

    def test_broken_line(self):
        self.assertIsNone(core.parse_stat("garbage"))
        self.assertIsNone(core.parse_stat("1 (x) S 1"))


class Group(unittest.TestCase):
    def test_sums_cpu_and_memory_per_name(self):
        prev = {1: ("app", 100, 10), 2: ("app", 50, 10), 3: ("other", 0, 10)}
        curr = {1: ("app", 150, 256), 2: ("app", 100, 256), 3: ("other", 20, 512)}
        # 2 s at 100 ticks/s on 2 cores: 400 ticks of capacity
        programs = core.group(prev, curr, 2.0, 100, 2, 4096)
        self.assertAlmostEqual(programs["app"]["cpu"], 25.0)
        self.assertAlmostEqual(programs["other"]["cpu"], 5.0)
        self.assertAlmostEqual(programs["app"]["memMb"], 2.0)

    def test_new_and_reused_pids_add_no_cpu(self):
        prev = {1: ("old", 100, 10)}
        curr = {1: ("new", 900, 256), 2: ("fresh", 900, 256)}
        programs = core.group(prev, curr, 2.0, 100, 1, 4096)
        self.assertEqual(programs["new"]["cpu"], 0.0)
        self.assertEqual(programs["fresh"]["cpu"], 0.0)

    def test_kernel_threads_are_left_out(self):
        programs = core.group({}, {1: ("kworker/0:1", 5, 0)}, 2.0, 100, 1, 4096)
        self.assertEqual(programs, {})


class Rank(unittest.TestCase):
    def test_top_by_cpu_then_by_memory_once_each(self):
        programs = {
            "busy": {"cpu": 50.0, "memMb": 10.0},
            "big": {"cpu": 0.0, "memMb": 900.0},
            "both": {"cpu": 30.0, "memMb": 800.0},
            "idle": {"cpu": 0.0, "memMb": 1.0},
        }
        self.assertEqual([p["name"] for p in core.rank(programs, 2)], ["busy", "both", "big"])

    def test_rounds_for_display(self):
        ranked = core.rank({"a": {"cpu": 12.345, "memMb": 99.6}}, 1)
        self.assertEqual(ranked, [{"name": "a", "cpu": 12.3, "memMb": 100}])


if __name__ == "__main__":
    unittest.main()
