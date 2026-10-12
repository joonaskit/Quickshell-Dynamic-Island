"""Tests for scripts/settings_backup.py, on temporary config folders. Run with ./test.sh."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import settings_backup as sb  # noqa: E402

SETTINGS = {"uiScale": 1.1, "use24Hour": False, "hueAppKey": "secret", "hueBridgeIp": "10.0.0.2"}
DOCK = [{"id": "dolphin", "name": "Files", "desktopFile": "org.kde.dolphin.desktop"},
        {"id": "krita", "name": "Krita", "desktopFile": "org.kde.krita.desktop"}]
USAGE = {"org.kde.dolphin": {"count": 3, "last": 1700000000000}}


def bundle_text(sections, **top):
    doc = {"format": sb.FORMAT, "version": sb.VERSION, "sections": sections}
    doc.update(top)
    return json.dumps(doc)


class ParseBundleTest(unittest.TestCase):
    def test_round_trips_a_built_bundle(self):
        text = json.dumps(sb.build_bundle({"settings": SETTINGS, "dock": DOCK}, with_secrets=True))
        self.assertEqual(sb.parse_bundle(text), {"settings": SETTINGS, "dock": DOCK})

    def test_rejects_what_is_not_an_export(self):
        for text in ["", "not json", "[]", "{}", json.dumps({"format": "other", "version": 1, "sections": {}}),
                     json.dumps(SETTINGS)]:
            with self.assertRaises(sb.BackupError, msg=text):
                sb.parse_bundle(text)

    def test_rejects_newer_and_invalid_versions(self):
        for version in [sb.VERSION + 1, 0, "1", None, True]:
            with self.assertRaises(sb.BackupError, msg=repr(version)):
                sb.parse_bundle(bundle_text({"settings": {}}, version=version))

    def test_rejects_malformed_sections(self):
        for sections in [{"settings": []}, {"dock": {}}, {"dock": [{"name": "no id"}]}, {"dock": ["x"]},
                         {"usage": {"a": 1}}, {"usage": {"a": {"count": "3", "last": 1}}}, {}, {"themes": {}}]:
            with self.assertRaises(sb.BackupError, msg=repr(sections)):
                sb.parse_bundle(bundle_text(sections))

    def test_ignores_unknown_sections_and_top_level_keys(self):
        text = bundle_text({"settings": {"uiScale": 1}, "themes": {"x": 1}}, madeUp=True)
        self.assertEqual(sb.parse_bundle(text), {"settings": {"uiScale": 1}})

    def test_keeps_unknown_setting_keys_for_the_shell_to_ignore(self):
        self.assertEqual(sb.parse_bundle(bundle_text({"settings": {"fromTheFuture": 1}})), {"settings": {"fromTheFuture": 1}})


class BuildBundleTest(unittest.TestCase):
    def test_leaves_private_keys_out_by_default(self):
        settings = sb.build_bundle({"settings": SETTINGS})["sections"]["settings"]
        self.assertEqual(settings, {"uiScale": 1.1, "use24Hour": False})

    def test_keeps_private_keys_when_asked(self):
        self.assertEqual(sb.build_bundle({"settings": SETTINGS}, with_secrets=True)["sections"]["settings"], SETTINGS)

    def test_header(self):
        bundle = sb.build_bundle({"dock": DOCK}, shell_version="abc123")
        self.assertEqual((bundle["format"], bundle["version"], bundle["shellVersion"]), (sb.FORMAT, sb.VERSION, "abc123"))
        self.assertTrue(bundle["exportedAt"])

    def test_refuses_to_export_a_broken_file(self):
        with self.assertRaises(sb.BackupError):
            sb.build_bundle({"dock": {"not": "a list"}})


class HelpersTest(unittest.TestCase):
    def test_merge_keeps_this_machines_private_values(self):
        merged = sb.merge_settings({"uiScale": 1.2}, {"uiScale": 1.0, "hueAppKey": "mine", "showSeconds": True})
        self.assertEqual(merged, {"uiScale": 1.2, "hueAppKey": "mine"})

    def test_merge_prefers_private_values_in_the_export(self):
        self.assertEqual(sb.merge_settings({"hueAppKey": "theirs"}, {"hueAppKey": "mine"}), {"hueAppKey": "theirs"})

    def test_missing_apps(self):
        self.assertEqual(sb.missing_apps(DOCK, {"org.kde.dolphin.desktop"}), ["Krita"])
        self.assertEqual(sb.missing_apps([{"id": "custom"}], set()), [])


class FilesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = os.path.join(self.tmp.name, "config")
        self.backups = os.path.join(self.tmp.name, "backups")
        self.export = os.path.join(self.tmp.name, "export.json")
        os.makedirs(self.config)

    def write(self, name, value):
        with open(os.path.join(self.config, name), "w") as f:
            json.dump(value, f)

    def read(self, name):
        with open(os.path.join(self.config, name)) as f:
            return json.load(f)

    def fill(self):
        self.write("settings.json", SETTINGS)
        self.write("dock_pinned.json", DOCK)
        self.write("launcher_usage.json", USAGE)

    def wipe(self):
        for name in os.listdir(self.config):
            os.unlink(os.path.join(self.config, name))

    def do_import(self, **kwargs):
        return sb.import_config(self.config, self.export, backups=self.backups, installed=set(), **kwargs)

    def test_round_trip_is_identical(self):
        self.fill()
        sb.export_config(self.config, self.export, include_usage=True, with_secrets=True)
        self.wipe()
        result = self.do_import()
        self.assertEqual(result["sections"], ["settings", "dock", "usage"])
        self.assertEqual(result["backup"], "")
        self.assertEqual((self.read("settings.json"), self.read("dock_pinned.json"), self.read("launcher_usage.json")),
                         (SETTINGS, DOCK, USAGE))

    def test_default_export_has_no_usage_and_no_secrets(self):
        self.fill()
        result = sb.export_config(self.config, self.export)
        self.assertEqual(result["sections"], ["settings", "dock"])
        with open(self.export) as f:
            text = f.read()
        self.assertNotIn("secret", text)
        self.assertNotIn("usage", json.loads(text)["sections"])

    def test_export_with_nothing_to_export_fails(self):
        with self.assertRaises(sb.BackupError):
            sb.export_config(self.config, self.export)
        self.assertFalse(os.path.exists(self.export))

    def test_import_backs_up_what_it_replaces(self):
        self.fill()
        with open(self.export, "w") as f:
            f.write(bundle_text({"settings": {"uiScale": 0.9}}))
        result = self.do_import()
        self.assertEqual(sorted(os.listdir(result["backup"])), ["settings.json"])
        with open(os.path.join(result["backup"], "settings.json")) as f:
            self.assertEqual(json.load(f), SETTINGS)
        self.assertEqual(self.read("settings.json"), {"uiScale": 0.9, "hueAppKey": "secret", "hueBridgeIp": "10.0.0.2"})
        self.assertEqual(self.read("dock_pinned.json"), DOCK)

    def test_invalid_import_changes_nothing(self):
        self.fill()
        for text in ["{ broken", bundle_text({"settings": {"uiScale": 2}, "dock": "nope"}),
                     bundle_text({"settings": {}}, version=99)]:
            with open(self.export, "w") as f:
                f.write(text)
            with self.assertRaises(sb.BackupError):
                self.do_import()
        self.assertEqual((self.read("settings.json"), self.read("dock_pinned.json")), (SETTINGS, DOCK))
        self.assertFalse(os.path.exists(self.backups))

    def test_missing_file_is_a_backup_error(self):
        with self.assertRaises(sb.BackupError):
            self.do_import()

    def test_import_only_chosen_sections(self):
        self.fill()
        with open(self.export, "w") as f:
            f.write(bundle_text({"settings": {"uiScale": 0.9}, "dock": [{"id": "kate"}]}))
        result = self.do_import(only=["dock"])
        self.assertEqual(result["sections"], ["dock"])
        self.assertEqual(self.read("dock_pinned.json"), [{"id": "kate"}])
        self.assertEqual(self.read("settings.json"), SETTINGS)
        with self.assertRaises(sb.BackupError):
            self.do_import(only=["usage"])
        with self.assertRaises(sb.BackupError):
            self.do_import(only=["themes"])

    def test_import_warns_about_apps_that_are_not_installed(self):
        with open(self.export, "w") as f:
            f.write(bundle_text({"dock": DOCK}))
        result = sb.import_config(self.config, self.export, backups=self.backups, installed={"org.kde.dolphin.desktop"})
        self.assertEqual(result["warnings"], ["Pinned apps that are not installed here: Krita"])

    def test_export_only_chosen_sections(self):
        self.fill()
        result = sb.export_config(self.config, self.export, only=["usage", "dock"])
        self.assertEqual(result["sections"], ["dock", "usage"])
        with self.assertRaises(sb.BackupError):
            sb.export_config(self.config, self.export, only=["themes"])

    def test_command_line(self):
        self.fill()
        self.assertEqual(sb.main(["x", "export", self.export, "--dir", self.config, "--json"]), 0)
        self.assertEqual(sb.main(["x", "import", os.path.join(self.tmp.name, "nope.json"), "--dir", self.config, "--json"]), 1)


if __name__ == "__main__":
    unittest.main()
