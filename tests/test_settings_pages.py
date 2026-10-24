"""Tests for the pure logic in scripts/settings_pages.py. Run with ./test.sh."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import settings_pages as sp  # noqa: E402

ENTRY = """[Desktop Entry]
Type=Application
NoDisplay=true
Exec=systemsettings kcm_kscreen
Icon=preferences-desktop-display
Name=Display
Name[fi]=Näyttö
Name[de_DE]=Anzeige
Comment=Resolution and scale
Keywords=monitor;screen;
Keywords[fi]=monitori;

[Desktop Action other]
Name=Other
"""


class ParseEntryTest(unittest.TestCase):
    def test_plain_values(self):
        f = sp.parse_entry(ENTRY, [])
        self.assertEqual(f["Name"], "Display")
        self.assertEqual(f["Exec"], "systemsettings kcm_kscreen")

    def test_translation_replaces_plain(self):
        f = sp.parse_entry(ENTRY, ["fi"])
        self.assertEqual(f["Name"], "Näyttö")
        self.assertEqual(f["Keywords"], "monitori;")

    def test_most_specific_locale_first(self):
        self.assertEqual(sp.parse_entry(ENTRY, ["de_DE", "de"])["Name"], "Anzeige")

    def test_missing_translation_keeps_plain(self):
        self.assertEqual(sp.parse_entry(ENTRY, ["sv"])["Comment"], "Resolution and scale")

    def test_other_groups_are_ignored(self):
        self.assertEqual(sp.parse_entry(ENTRY, [])["Name"], "Display")


class PageTest(unittest.TestCase):
    def test_page(self):
        page = sp.page_from_entry("kcm_kscreen.desktop", sp.parse_entry(ENTRY, []))
        self.assertEqual(page["id"], "kcm_kscreen")
        self.assertEqual(page["keywords"], ["monitor", "screen"])
        self.assertEqual(page["command"], ["systemsettings", "kcm_kscreen"])

    def test_field_codes_are_dropped(self):
        self.assertEqual(sp.split_exec("kcmshell6 kcm_x %U"), ["kcmshell6", "kcm_x"])

    def test_other_launchers_are_skipped(self):
        fields = sp.parse_entry(ENTRY.replace("systemsettings kcm_kscreen", "evil kcm_kscreen"), [])
        self.assertIsNone(sp.page_from_entry("kcm_kscreen.desktop", fields))

    def test_only_kcm_files(self):
        self.assertIsNone(sp.page_from_entry("firefox.desktop", sp.parse_entry(ENTRY, [])))

    def test_hidden_is_skipped(self):
        fields = sp.parse_entry(ENTRY.replace("NoDisplay=true", "Hidden=true"), [])
        self.assertIsNone(sp.page_from_entry("kcm_kscreen.desktop", fields))

    def test_no_name_is_skipped(self):
        fields = sp.parse_entry(ENTRY.replace("Name=Display", "Name="), [])
        self.assertIsNone(sp.page_from_entry("kcm_kscreen.desktop", fields))


class CollectTest(unittest.TestCase):
    def test_earlier_folder_wins_and_result_is_sorted(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            for base, title in ((a, "Mine"), (b, "Theirs")):
                os.makedirs(os.path.join(base, "applications"))
                with open(os.path.join(base, "applications", "kcm_kscreen.desktop"), "w") as f:
                    f.write(ENTRY.replace("Name=Display", "Name=" + title))
            with open(os.path.join(b, "applications", "kcm_access.desktop"), "w") as f:
                f.write(ENTRY.replace("kcm_kscreen", "kcm_access").replace("Name=Display", "Name=Accessibility"))
            pages = sp.collect([a, b, "/does/not/exist"], [])
        self.assertEqual([p["name"] for p in pages], ["Accessibility", "Mine"])


if __name__ == "__main__":
    unittest.main()
