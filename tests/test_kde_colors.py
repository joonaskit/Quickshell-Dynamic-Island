"""Tests for scripts/kde_colors.py. Run with ./test.sh."""
import configparser
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import kde_colors  # noqa: E402

THEME = {
    "version": 1,
    "scheme": "dark",
    "colors": {
        "background": "#000000",
        "surface": "#1c1c1e",
        "surfaceRaised": "#2c2c2e",
        "textPrimary": "#ffffff",
        "textSecondary": "#98989d",
        "textTertiary": "#636366",
        "onAccent": "#ffffff",
        "accent": "#bf5af2",
        "success": "#30d158",
        "warning": "#ff9f0a",
        "danger": "#ff453a",
        "palette": {"blue": "#0a84ff", "purple": "#bf5af2"},
    },
}


def parse(text):
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read_string(text)
    return parser


class ColorTest(unittest.TestCase):
    def test_parse_color(self):
        self.assertEqual(kde_colors.parse_color("#0a84ff"), (10, 132, 255))
        self.assertIsNone(kde_colors.parse_color("0a84ff"))
        self.assertIsNone(kde_colors.parse_color("#0a84f"))
        self.assertIsNone(kde_colors.parse_color("#zzzzzz"))
        self.assertIsNone(kde_colors.parse_color(None))

    def test_mix(self):
        self.assertEqual(kde_colors.mix((0, 0, 0), (255, 255, 255), 0), (0, 0, 0))
        self.assertEqual(kde_colors.mix((0, 0, 0), (255, 255, 255), 1), (255, 255, 255))
        self.assertEqual(kde_colors.mix((0, 0, 0), (200, 100, 50), 0.5), (100, 50, 25))

    def test_missing_and_invalid_colors_use_the_defaults(self):
        theme = {"scheme": "light", "colors": {"accent": "#123456", "surface": "nope"}}
        scheme, colors = kde_colors.resolve_colors(theme)
        self.assertEqual(scheme, "light")
        self.assertEqual(colors["accent"], (0x12, 0x34, 0x56))
        self.assertEqual(colors["surface"], kde_colors.parse_color(kde_colors.DEFAULT_COLORS["light"]["surface"]))

    def test_anything_but_light_is_dark(self):
        self.assertEqual(kde_colors.resolve_colors({"scheme": "sepia"})[0], "dark")
        self.assertEqual(kde_colors.resolve_colors(None)[0], "dark")


class BuildSchemeTest(unittest.TestCase):
    def setUp(self):
        self.scheme = parse(kde_colors.build_scheme(THEME, "QuickshellIsland"))

    def test_has_every_group_kde_reads(self):
        for group in ("Colors:View", "Colors:Window", "Colors:Header", "Colors:Header][Inactive",
                      "Colors:Button", "Colors:Selection", "Colors:Tooltip", "Colors:Complementary",
                      "ColorEffects:Disabled", "ColorEffects:Inactive", "General", "KDE", "WM"):
            self.assertIn(group, self.scheme, group)

    def test_every_color_group_has_every_role(self):
        roles = set(kde_colors.section((0, 0, 0), (0, 0, 0), kde_colors.resolve_colors(THEME)[1]))
        for group in self.scheme.sections():
            if group.startswith("Colors:"):
                self.assertEqual(set(self.scheme[group]), roles, group)

    def test_names_the_scheme(self):
        self.assertEqual(self.scheme["General"]["ColorScheme"], "QuickshellIsland")
        self.assertEqual(self.scheme["General"]["Name"], "Quickshell Island")

    def test_gray_base_builds_on_the_surface(self):
        # As Filehouse: the window is the surface, cards and controls mix in the text colour
        self.assertEqual(self.scheme["Colors:View"]["BackgroundNormal"], "28,28,30")
        self.assertEqual(self.scheme["Colors:Window"]["BackgroundNormal"], "28,28,30")
        self.assertEqual(self.scheme["Colors:Tooltip"]["BackgroundNormal"], "37,37,39")
        self.assertEqual(self.scheme["Colors:Button"]["BackgroundNormal"], "51,51,52")

    def test_black_base_builds_on_the_background(self):
        black = parse(kde_colors.build_scheme(THEME, "QuickshellIsland", "black"))
        self.assertEqual(black["Colors:View"]["BackgroundNormal"], "0,0,0")
        self.assertEqual(black["Colors:Window"]["BackgroundNormal"], "28,28,30")
        self.assertEqual(black["Colors:Button"]["BackgroundNormal"], "44,44,46")
        self.assertEqual(black["WM"]["activeBackground"], "28,28,30")

    def test_maps_the_text_roles(self):
        self.assertEqual(self.scheme["Colors:Window"]["ForegroundNormal"], "255,255,255")
        self.assertEqual(self.scheme["Colors:Window"]["ForegroundInactive"], "152,152,157")
        self.assertEqual(self.scheme["Colors:Window"]["ForegroundNegative"], "255,69,58")
        self.assertEqual(self.scheme["Colors:Window"]["ForegroundLink"], "10,132,255")

    def test_accent_drives_selection_and_focus(self):
        self.assertEqual(self.scheme["Colors:Selection"]["BackgroundNormal"], "191,90,242")
        self.assertEqual(self.scheme["Colors:Selection"]["ForegroundNormal"], "255,255,255")
        self.assertEqual(self.scheme["Colors:View"]["DecorationFocus"], "191,90,242")
        self.assertEqual(self.scheme["Colors:Button"]["DecorationHover"], "191,90,242")

    def test_titlebars(self):
        self.assertEqual(self.scheme["WM"]["activeBackground"], "28,28,30")
        self.assertEqual(self.scheme["WM"]["activeForeground"], "255,255,255")
        self.assertEqual(self.scheme["WM"]["inactiveForeground"], "99,99,102")

    def test_values_are_rgb_triples(self):
        for group in self.scheme.sections():
            if group.startswith("Colors:") or group == "WM":
                for key, value in self.scheme[group].items():
                    parts = value.split(",")
                    self.assertEqual(len(parts), 3, (group, key))
                    self.assertTrue(all(0 <= int(p) <= 255 for p in parts), (group, key))

    def test_every_base_has_the_same_groups(self):
        black = parse(kde_colors.build_scheme(THEME, "QuickshellIsland", "black"))
        self.assertEqual(black.sections(), self.scheme.sections())

    def test_follows_the_theme(self):
        changed = json.loads(json.dumps(THEME))
        changed["colors"]["accent"] = "#30d158"
        self.assertNotEqual(kde_colors.build_scheme(THEME, "QuickshellIsland"),
                            kde_colors.build_scheme(changed, "QuickshellIsland"))


class CommandTest(unittest.TestCase):
    """apply and restore against a fake home, with plasma-apply-colorscheme replaced."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        root = self.dir.name
        env = mock.patch.dict(os.environ, {
            "XDG_CONFIG_HOME": os.path.join(root, "config"),
            "XDG_DATA_HOME": os.path.join(root, "data"),
            "XDG_STATE_HOME": os.path.join(root, "state"),
        })
        env.start()
        self.addCleanup(env.stop)
        self.applied = []
        self.failing = set()
        self.set_current("Andromeda")

    def set_current(self, name):
        os.makedirs(os.path.join(self.dir.name, "config"), exist_ok=True)
        with open(os.path.join(self.dir.name, "config", "kdeglobals"), "w", encoding="utf-8") as f:
            f.write("[KDE]\nColorScheme=Wrong\n\n[General]\nColorScheme=%s\nfont=Cantarell\n" % name)

    def fake_run(self, name):
        if name in self.failing:
            raise kde_colors.SchemeError("no such scheme")
        self.applied.append(name)
        self.set_current(name)

    def schemes(self):
        directory = os.path.join(self.dir.name, "data", "color-schemes")
        return sorted(os.listdir(directory)) if os.path.isdir(directory) else []

    def test_reads_the_general_group_only(self):
        self.assertEqual(kde_colors.current_scheme(), "Andromeda")

    def test_no_kdeglobals_means_no_scheme(self):
        os.remove(os.path.join(self.dir.name, "config", "kdeglobals"))
        self.assertEqual(kde_colors.current_scheme(), "")

    def test_apply_writes_and_applies_and_saves_the_previous_scheme(self):
        self.assertEqual(kde_colors.apply(THEME, run=self.fake_run), "applied")
        self.assertEqual(self.applied, ["QuickshellIsland"])
        self.assertEqual(self.schemes(), ["QuickshellIsland.colors"])
        self.assertEqual(kde_colors.load_state(), {"previous": "Andromeda"})

    def test_an_update_alternates_names_and_keeps_one_file(self):
        kde_colors.apply(THEME, run=self.fake_run)
        changed = json.loads(json.dumps(THEME))
        changed["colors"]["accent"] = "#30d158"
        self.assertEqual(kde_colors.apply(changed, run=self.fake_run), "applied")
        self.assertEqual(self.applied, ["QuickshellIsland", "QuickshellIslandAlt"])
        self.assertEqual(self.schemes(), ["QuickshellIslandAlt.colors"])
        kde_colors.apply(THEME, run=self.fake_run)
        self.assertEqual(self.applied[-1], "QuickshellIsland")
        # The scheme from before the first apply is kept
        self.assertEqual(kde_colors.load_state(), {"previous": "Andromeda"})

    def test_a_new_base_is_applied(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.assertEqual(kde_colors.apply(THEME, "black", run=self.fake_run), "applied")
        self.assertEqual(self.applied, ["QuickshellIsland", "QuickshellIslandAlt"])

    def test_unchanged_theme_is_not_applied_again(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.assertEqual(kde_colors.apply(THEME, run=self.fake_run), "unchanged")
        self.assertEqual(self.applied, ["QuickshellIsland"])

    def test_another_scheme_picked_since_wins(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.set_current("Nordic")
        self.assertEqual(kde_colors.apply(THEME, run=self.fake_run), "overridden")
        self.assertEqual(self.applied, ["QuickshellIsland"])
        self.assertEqual(self.schemes(), [])
        self.assertIsNone(kde_colors.load_state())
        self.assertEqual(kde_colors.current_scheme(), "Nordic")

    def test_failed_first_apply_leaves_nothing_behind(self):
        self.failing.add("QuickshellIsland")
        with self.assertRaises(kde_colors.SchemeError):
            kde_colors.apply(THEME, run=self.fake_run)
        self.assertEqual(self.schemes(), [])
        self.assertIsNone(kde_colors.load_state())

    def test_restore_goes_back_to_the_previous_scheme(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.assertEqual(kde_colors.restore(run=self.fake_run), "restored")
        self.assertEqual(self.applied[-1], "Andromeda")
        self.assertEqual(self.schemes(), [])
        self.assertIsNone(kde_colors.load_state())

    def test_restore_falls_back_to_breeze_when_the_previous_scheme_is_gone(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.failing.add("Andromeda")
        kde_colors.restore(run=self.fake_run)
        self.assertEqual(kde_colors.current_scheme(), kde_colors.DEFAULT_SCHEME)

    def test_restore_after_the_user_moved_on_only_cleans_up(self):
        kde_colors.apply(THEME, run=self.fake_run)
        self.set_current("Nordic")
        self.assertEqual(kde_colors.restore(run=self.fake_run), "restored")
        self.assertEqual(self.applied, ["QuickshellIsland"])
        self.assertEqual(kde_colors.current_scheme(), "Nordic")
        self.assertEqual(self.schemes(), [])

    def test_restore_with_nothing_applied_does_nothing(self):
        self.assertEqual(kde_colors.restore(run=self.fake_run), "nothing")
        self.assertEqual(self.applied, [])

    def test_previous_scheme_unknown_restores_breeze(self):
        # The shell's scheme is active but its state is lost
        self.set_current("QuickshellIsland")
        kde_colors.restore(run=self.fake_run)
        self.assertEqual(self.applied, [kde_colors.DEFAULT_SCHEME])


class MainTest(unittest.TestCase):
    def test_usage(self):
        with mock.patch("sys.stderr"):
            self.assertEqual(kde_colors.main(["kde_colors.py"]), 2)
            self.assertEqual(kde_colors.main(["kde_colors.py", "apply"]), 2)
            self.assertEqual(kde_colors.main(["kde_colors.py", "apply", "{}", "white"]), 2)

    def test_invalid_json(self):
        with mock.patch("sys.stderr"):
            self.assertEqual(kde_colors.main(["kde_colors.py", "apply", "{"]), 1)


if __name__ == "__main__":
    unittest.main()
