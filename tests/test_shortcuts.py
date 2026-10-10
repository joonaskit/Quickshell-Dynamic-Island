"""Tests for the pure logic in scripts/shortcuts.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import shortcuts as sc  # noqa: E402


class KeyTextTest(unittest.TestCase):
    def test_meta_and_letter(self):
        self.assertEqual(sc.key_text(sc.META | 0x56), "Meta+V")

    def test_modifier_order_matches_kde(self):
        code = sc.SHIFT | sc.ALT | sc.CTRL | sc.META | sc.F1 + 8
        self.assertEqual(sc.key_text(code), "Meta+Ctrl+Alt+Shift+F9")

    def test_bare_meta(self):
        self.assertEqual(sc.key_text(sc.KEY_META), "Meta")

    def test_special_keys(self):
        self.assertEqual(sc.key_text(0x01000072), "Volume Up")
        self.assertEqual(sc.key_text(sc.CTRL | 0x20), "Ctrl+Space")

    def test_unbound(self):
        self.assertEqual(sc.key_text(0), "")


class ValidCodeTest(unittest.TestCase):
    def test_plain_letter_rejected(self):
        self.assertFalse(sc.valid_code(0x41))

    def test_shift_letter_rejected(self):
        self.assertFalse(sc.valid_code(sc.SHIFT | 0x41))

    def test_ctrl_letter_accepted(self):
        self.assertTrue(sc.valid_code(sc.CTRL | 0x41))

    def test_function_and_media_keys_accepted_alone(self):
        self.assertTrue(sc.valid_code(sc.F1))
        self.assertTrue(sc.valid_code(0x01000072))

    def test_bare_meta_accepted_but_not_other_modifiers(self):
        self.assertTrue(sc.valid_code(sc.KEY_META))
        self.assertFalse(sc.valid_code(sc.META))
        self.assertFalse(sc.valid_code(sc.SHIFT))


class ParseExecTest(unittest.TestCase):
    def test_run_sh_aliases(self):
        self.assertEqual(sc.parse_exec("/home/u/qs/run.sh launcher"), ("launcher", "toggle"))
        self.assertEqual(sc.parse_exec("/home/u/qs/run.sh -v"), ("clipboard", "toggle"))
        self.assertEqual(sc.parse_exec("/home/u/qs/run.sh -w"), ("launcher", "windows"))

    def test_run_sh_ipc(self):
        self.assertEqual(sc.parse_exec("/qs/run.sh ipc system startTimer 5"), ("system", "startTimer", "5"))
        self.assertEqual(sc.parse_exec("/qs/run.sh -i system volumeUp"), ("system", "volumeUp"))

    def test_quickshell_ipc(self):
        self.assertEqual(sc.parse_exec("quickshell ipc -p /qs call island toggle"), ("island", "toggle"))

    def test_other_programs_ignored(self):
        self.assertIsNone(sc.parse_exec("konsole"))
        self.assertIsNone(sc.parse_exec(""))
        self.assertIsNone(sc.parse_exec("/qs/run.sh"))

    def test_generated_exec_is_recognised(self):
        for action in sc.ACTIONS:
            self.assertEqual(sc.parse_exec(sc.exec_line(action)), (action[3], action[4], *action[5]))


class CatalogueTest(unittest.TestCase):
    def test_ids_and_commands_are_unique(self):
        self.assertEqual(len({a[0] for a in sc.ACTIONS}), len(sc.ACTIONS))
        self.assertEqual(len({(a[3], a[4], *a[5]) for a in sc.ACTIONS}), len(sc.ACTIONS))

    def test_component_path(self):
        self.assertEqual(sc.component_path("net.local.run.sh-3.desktop"), "/component/net_local_run_sh_3_desktop")


if __name__ == "__main__":
    unittest.main()
