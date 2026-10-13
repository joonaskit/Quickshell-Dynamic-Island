"""Tests for scripts/island_run_core.py. Run with ./test.sh."""
import os
import signal
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import island_run_core as core  # noqa: E402


class PercentTest(unittest.TestCase):
    def test_rsync_line(self):
        self.assertAlmostEqual(core.parse_percent("  1.23G  45%   12.3MB/s    0:01:02"), 0.45)

    def test_yt_dlp_line(self):
        self.assertAlmostEqual(core.parse_percent("[download]  45.3% of 10.00MiB at 1.2MiB/s ETA 00:05"), 0.453)

    def test_last_percentage_wins(self):
        self.assertAlmostEqual(core.parse_percent("10% 20% 30%"), 0.30)

    def test_over_100_is_ignored(self):
        self.assertIsNone(core.parse_percent("CPU 250% busy"))

    def test_no_percentage(self):
        self.assertIsNone(core.parse_percent("Installing foo"))


class FractionTest(unittest.TestCase):
    def test_dnf_line(self):
        self.assertAlmostEqual(core.parse_fraction("[3/12] Installing foo-1.0"), 0.25)

    def test_padded(self):
        self.assertAlmostEqual(core.parse_fraction("[ 12/340] Building x.o"), 12 / 340)

    def test_date_is_not_progress(self):
        self.assertIsNone(core.parse_fraction("Built on 10/12/2026"))

    def test_done_above_total_is_ignored(self):
        self.assertIsNone(core.parse_fraction("[5/3]"))

    def test_zero_total_is_ignored(self):
        self.assertIsNone(core.parse_fraction("[0/0]"))


class AutoTest(unittest.TestCase):
    def test_percent_first(self):
        self.assertAlmostEqual(core.parse_auto("[3/12] 50%"), 0.5)

    def test_falls_back_to_fraction(self):
        self.assertAlmostEqual(core.parse_auto("[6/12] Linking"), 0.5)

    def test_none_parser_never_reports(self):
        self.assertIsNone(core.PARSERS["none"]("50%"))


class OutputTest(unittest.TestCase):
    def test_carriage_return_ends_a_line(self):
        lines, rest = core.split_output("", "10%\r20%\r30%")
        self.assertEqual(lines, ["10%", "20%"])
        self.assertEqual(rest, "30%")

    def test_line_split_over_two_chunks(self):
        lines, rest = core.split_output("", "downlo")
        self.assertEqual((lines, rest), ([], "downlo"))
        lines, rest = core.split_output(rest, "ading\nnext")
        self.assertEqual(lines, ["downloading"])
        self.assertEqual(rest, "next")

    def test_blank_lines_are_dropped(self):
        lines, _ = core.split_output("", "a\n\n\nb\n")
        self.assertEqual(lines, ["a", "b"])

    def test_colour_codes_are_removed(self):
        lines, _ = core.split_output("", "\x1b[32mok\x1b[0m\n")
        self.assertEqual(lines, ["ok"])

    def test_cursor_codes_are_removed(self):
        self.assertEqual(core.strip_ansi("\x1b[2K\x1b[1Gprogress"), "progress")


class TitleTest(unittest.TestCase):
    def test_command_line(self):
        self.assertEqual(core.default_title(["rsync", "-a", "src", "dst"]), "rsync -a src dst")

    def test_long_title_is_shortened(self):
        title = core.default_title(["echo", "x" * 200])
        self.assertEqual(len(title), core.TITLE_LIMIT)
        self.assertTrue(title.endswith("…"))


class ExitTest(unittest.TestCase):
    def test_success(self):
        self.assertEqual(core.describe_exit("t", 0)["state"], "done")

    def test_failure_names_code_and_last_line(self):
        result = core.describe_exit("t", 2, "No space left on device")
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["error"], "Exited with code 2: No space left on device")

    def test_failure_without_output(self):
        self.assertEqual(core.describe_exit("t", 1)["error"], "Exited with code 1")

    def test_stopping_is_cancelled(self):
        for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            self.assertEqual(core.describe_exit("t", -number)["state"], "cancelled")

    def test_other_signal_is_a_failure(self):
        result = core.describe_exit("t", -signal.SIGSEGV)
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["error"], "Killed by SIGSEGV")

    def test_exit_status_like_a_shell(self):
        self.assertEqual(core.exit_status(3), 3)
        self.assertEqual(core.exit_status(-signal.SIGTERM), 143)


if __name__ == "__main__":
    unittest.main()
