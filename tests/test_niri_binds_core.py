"""Tests for scripts/niri_binds_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import niri_binds_core as core  # noqa: E402

SHELL = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

CONFIG = """input {
    keyboard { xkb { layout "fi"; } }
}

// Comment with a { brace
binds {
    // Overlay
    Mod+F1 { show-hotkey-overlay; }
    Mod+T hotkey-overlay-title="Open a Terminal" { spawn "konsole"; }
    Mod+Space repeat=false { spawn "quickshell" "ipc" "-p" "%s" "call" "dial" "toggle"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    Mod+Left  { focus-column-left; }
    Mod+H     { focus-column-left; }
    Mod+Q repeat=false { close-window; } // trailing
    /-Mod+X { quit; }
    Mod+1 { focus-workspace 1; }
    Mod+Minus { set-column-width "-10%%"; }
    Mod+Shift+E {
        quit;
    }
}
""" % SHELL


def rows(text):
    out = {}
    for group in core.list_actions(text, SHELL)["groups"]:
        for action in group["actions"]:
            out[action["id"]] = dict(action, group=group["name"])
    return out


class TokenizeTest(unittest.TestCase):
    def test_comments_dropped(self):
        kinds = [t.kind for t in core.tokenize("a // b {\n/* c { */ d")]
        self.assertEqual(kinds, ["word", "newline", "word"])

    def test_strings(self):
        toks = core.tokenize(r'"a\"b" r#"x"y"#')
        self.assertEqual([t.value for t in toks], ['a"b', 'x"y'])

    def test_unclosed_string(self):
        with self.assertRaises(ValueError):
            core.tokenize('a "b')


class ListTest(unittest.TestCase):
    def setUp(self):
        self.rows = rows(CONFIG)

    def test_groups_in_order(self):
        names = [g["name"] for g in core.list_actions(CONFIG, SHELL)["groups"]]
        self.assertEqual(names, core.GROUPS)

    def test_several_keys_for_one_action(self):
        self.assertEqual(self.rows["focus-column-left"]["keys"], ["Mod+Left", "Mod+H"])

    def test_shell_action_found(self):
        dial = self.rows["shell:dial.toggle"]
        self.assertEqual(dial["keys"], ["Mod+Space"])
        self.assertEqual(dial["group"], "Shell")

    def test_unbound_catalogue_action_listed(self):
        self.assertEqual(self.rows["toggle-overview"]["keys"], [])
        self.assertEqual(self.rows["shell:clipboard.toggle"]["keys"], [])

    def test_app_titles(self):
        self.assertEqual(self.rows['spawn "konsole"']["title"], "Open a Terminal")
        mute = self.rows['spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"']
        self.assertEqual(mute["group"], "Apps")
        self.assertEqual(mute["title"], "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")

    def test_arguments_and_multiline(self):
        self.assertEqual(self.rows["focus-workspace 1"]["keys"], ["Mod+1"])
        self.assertEqual(self.rows['set-column-width "-10%"']["keys"], ["Mod+Minus"])
        self.assertEqual(self.rows["quit"]["keys"], ["Mod+Shift+E"])  # /- one skipped

    def test_unknown_action_grouped_by_name(self):
        r = rows("binds {\n    Mod+Z { move-window-to-monitor-left; }\n}\n")
        self.assertEqual(r["move-window-to-monitor-left"]["group"], "Monitors")
        self.assertEqual(r["move-window-to-monitor-left"]["title"], "Move window to monitor left")

    def test_other_checkout_is_not_this_shell(self):
        text = 'binds {\n    Mod+Z { spawn "quickshell" "ipc" "-p" "/elsewhere" "call" "dial" "toggle"; }\n}\n'
        r = rows(text)
        self.assertEqual(r["shell:dial.toggle"]["keys"], [])
        self.assertEqual(r['spawn "quickshell" "ipc" "-p" "/elsewhere" "call" "dial" "toggle"']["group"], "Apps")


class KeyTest(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(core.normalize_key("Mod+Shift+t"), core.normalize_key("Shift+Super+T"))
        self.assertEqual(core.normalize_key("Control+A"), core.normalize_key("Ctrl+a"))
        self.assertNotEqual(core.normalize_key("Mod+T"), core.normalize_key("Mod+Shift+T"))


class SetKeyTest(unittest.TestCase):
    def test_replace_keeps_properties_and_comment(self):
        out = core.set_key(CONFIG, "close-window", "Mod+Q", "Mod+W", SHELL)
        self.assertIn("    Mod+W repeat=false { close-window; } // trailing\n", out)
        self.assertNotIn("Mod+Q", out)

    def test_add_goes_beside_the_others(self):
        out = core.set_key(CONFIG, "focus-column-left", "", "Mod+A", SHELL)
        self.assertIn("    Mod+H     { focus-column-left; }\n    Mod+A { focus-column-left; }\n", out)

    def test_add_copies_properties_but_not_title(self):
        out = core.set_key(CONFIG, 'spawn "konsole"', "", "Mod+Return", SHELL)
        self.assertIn('    Mod+Return { spawn "konsole"; }\n', out)

    def test_add_unbound_goes_at_end_of_block(self):
        out = core.set_key(CONFIG, "toggle-overview", "", "Mod+O", SHELL)
        self.assertTrue(out.endswith("    Mod+O { toggle-overview; }\n}\n"))

    def test_add_shell_action(self):
        out = core.set_key(CONFIG, "shell:clipboard.toggle", "", "Mod+V", SHELL)
        line = 'Mod+V repeat=false { spawn "quickshell" "ipc" "-p" "%s" "call" "clipboard" "toggle"; }' % SHELL
        self.assertIn(line, out)
        self.assertEqual(rows(out)["shell:clipboard.toggle"]["keys"], ["Mod+V"])

    def test_conflict(self):
        with self.assertRaises(core.EditError) as ctx:
            core.set_key(CONFIG, "toggle-overview", "", "Mod+Q", SHELL)
        self.assertEqual(ctx.exception.conflict["id"], "close-window")
        self.assertEqual(ctx.exception.conflict["title"], "Close window")

    def test_conflict_ignores_case_and_spelling(self):
        with self.assertRaises(core.EditError):
            core.set_key(CONFIG, "toggle-overview", "", "Super+left", SHELL)

    def test_force_takes_the_key(self):
        out = core.set_key(CONFIG, "toggle-overview", "", "Mod+Q", SHELL, force=True)
        r = rows(out)
        self.assertEqual(r["toggle-overview"]["keys"], ["Mod+Q"])
        self.assertEqual(r["close-window"]["keys"], [])
        self.assertNotIn("// trailing", out)

    def test_same_key_again_is_no_change(self):
        self.assertEqual(core.set_key(CONFIG, "focus-column-left", "", "Mod+H", SHELL), CONFIG)

    def test_rebinding_to_own_other_key_drops_old(self):
        out = core.set_key(CONFIG, "focus-column-left", "Mod+Left", "Mod+H", SHELL)
        self.assertEqual(rows(out)["focus-column-left"]["keys"], ["Mod+H"])

    def test_multiline_bind_rekeyed(self):
        out = core.set_key(CONFIG, "quit", "Mod+Shift+E", "Ctrl+Alt+Delete", SHELL)
        self.assertIn("    Ctrl+Alt+Delete {\n        quit;\n    }\n", out)

    def test_no_binds_block(self):
        out = core.set_key("input {}\n", "toggle-overview", "", "Mod+O", SHELL)
        self.assertEqual(out, "input {}\n\nbinds {\n    Mod+O { toggle-overview; }\n}\n")

    def test_invalid_key_text(self):
        for key in ("", "Mod+", "Mod+A B"):
            with self.assertRaises(core.EditError):
                core.set_key(CONFIG, "toggle-overview", "", key, SHELL)

    def test_unknown_action(self):
        with self.assertRaises(core.EditError):
            core.set_key(CONFIG, "not-an-action", "", "Mod+Z", SHELL)


class RemoveKeyTest(unittest.TestCase):
    def test_removes_line(self):
        out = core.remove_key(CONFIG, "focus-column-left", "Mod+Left", SHELL)
        self.assertNotIn("Mod+Left", out)
        self.assertIn("    Mod+H     { focus-column-left; }\n", out)
        self.assertEqual(out.count("\n"), CONFIG.count("\n") - 1)

    def test_removes_multiline_node(self):
        out = core.remove_key(CONFIG, "quit", "Mod+Shift+E", SHELL)
        self.assertNotIn("Mod+Shift+E", out)
        self.assertNotIn("        quit;\n", out)

    def test_missing(self):
        with self.assertRaises(core.EditError):
            core.remove_key(CONFIG, "focus-column-left", "Mod+Z", SHELL)


class ValidateErrorTest(unittest.TestCase):
    def test_reason(self):
        stderr = ("Error:   \x1b[31m×\x1b[0m invalid keybind\n  ├─▶ invalid keybind\n"
                  "  ╰─▶ invalid key: Bogus\n")
        self.assertEqual(core.validate_error(stderr), "invalid key: Bogus")

    def test_heading_only(self):
        self.assertEqual(core.validate_error("Error:   × duplicate keybind\n"), "duplicate keybind")


if __name__ == "__main__":
    unittest.main()
