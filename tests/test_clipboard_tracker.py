"""Tests for scripts/clipboard_tracker.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import clipboard_tracker as ct  # noqa: E402


class ClassifyTest(unittest.TestCase):
    def test_plain_text(self):
        self.assertEqual(ct.classify_text("hello world"), ("text", False))

    def test_url(self):
        self.assertEqual(ct.classify_text("https://example.com/a?b=1\n"), ("url", False))

    def test_text_containing_url_is_text(self):
        self.assertEqual(ct.classify_text("see https://example.com now")[0], "text")

    def test_multiline_url_list_is_text(self):
        self.assertEqual(ct.classify_text("https://a.com\nhttps://b.com")[0], "text")

    def test_github_token_is_sensitive(self):
        self.assertTrue(ct.classify_text("ghp_" + "a1B2c3D4e5" * 4)[1])

    def test_private_key_is_sensitive(self):
        self.assertTrue(ct.classify_text("-----BEGIN OPENSSH PRIVATE KEY-----\nabc")[1])

    def test_password_assignment_is_sensitive(self):
        self.assertTrue(ct.classify_text("password = hunter2hunter2")[1])

    def test_random_token_is_sensitive(self):
        self.assertTrue(ct.classify_text("q8Zr3LmX9vB2nT7kWp4YcD1aF6hJ0sGe")[1])

    def test_url_with_long_path_is_not_sensitive(self):
        self.assertFalse(ct.classify_text("https://example.com/Some/Long/Path/AbC123xyz456")[1])

    def test_long_plain_word_is_not_sensitive(self):
        self.assertFalse(ct.classify_text("internationalizationlocalization")[1])


class RecordTest(unittest.TestCase):
    def test_blank_text_is_skipped(self):
        self.assertIsNone(ct.build_text_record("  \n\t"))

    def test_huge_text_is_skipped(self):
        self.assertIsNone(ct.build_text_record("a" * (ct.MAX_CHARS + 1)))

    def test_metadata(self):
        r = ct.build_text_record("héllo\nworld", now_ms=5)
        self.assertEqual((r["chars"], r["size"], r["lines"], r["time"]), (11, 12, 2, 5))

    def test_trailing_newline_does_not_add_a_line(self):
        self.assertEqual(ct.build_text_record("one\n")["lines"], 1)


class UriListTest(unittest.TestCase):
    def test_decodes_paths_and_ignores_other_lines(self):
        raw = "# comment\r\nfile:///home/u/My%20File.txt\r\nhttps://x.y\r\n"
        self.assertEqual(ct.parse_uri_list(raw), ["/home/u/My File.txt"])


if __name__ == "__main__":
    unittest.main()
