"""Tests for scripts/shortcuts.py, with D-Bus mocked. Run with ./test.sh."""
import io
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

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


class RunsThisShellTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.shell = os.path.join(self.tmp.name, "island")
        self.other = os.path.join(self.tmp.name, "checkout")
        for d in (self.shell, self.other):
            os.makedirs(d)
            open(os.path.join(d, "shell.qml"), "w").close()
        patcher = mock.patch.object(sc, "run_sh_path", lambda: os.path.join(self.shell, "run.sh"))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_own_run_sh(self):
        self.assertTrue(sc.runs_this_shell(self.shell + "/run.sh -l"))
        self.assertTrue(sc.runs_this_shell(sc.exec_line(sc.ACTIONS[0])))

    def test_run_sh_of_another_copy(self):
        self.assertFalse(sc.runs_this_shell(self.other + "/run.sh -l"))

    def test_run_sh_from_path_is_unknown(self):
        self.assertFalse(sc.runs_this_shell("run.sh -l"))

    def test_tilde_is_expanded(self):
        with mock.patch.dict(os.environ, {"HOME": self.tmp.name}):
            self.assertTrue(sc.runs_this_shell("~/island/run.sh -l"))
            self.assertFalse(sc.runs_this_shell("~/checkout/run.sh -l"))

    def test_quickshell_path(self):
        self.assertTrue(sc.runs_this_shell("quickshell ipc -p %s call launcher toggle" % self.shell))
        self.assertTrue(sc.runs_this_shell("quickshell ipc -p %s/shell.qml call launcher toggle" % self.shell))
        self.assertFalse(sc.runs_this_shell("quickshell ipc -p %s call launcher toggle" % self.other))
        self.assertFalse(sc.runs_this_shell("quickshell ipc call launcher toggle"))


class CatalogueTest(unittest.TestCase):
    def test_ids_and_commands_are_unique(self):
        self.assertEqual(len({a[0] for a in sc.ACTIONS}), len(sc.ACTIONS))
        self.assertEqual(len({(a[3], a[4], *a[5]) for a in sc.ACTIONS}), len(sc.ACTIONS))

    def test_component_path(self):
        self.assertEqual(sc.component_path("net.local.run.sh-3.desktop"), "/component/net_local_run_sh_3_desktop")


class ReleaseKeyTest(unittest.TestCase):
    CLOSE = ["Window Close", "Close Window", "kwin", "KWin", "default", "Default Context", [150994995, 42], [150994995]]

    def released(self, info):
        calls = []
        with mock.patch.object(sc, "accel", lambda *args: calls.append(args)):
            sc.release_key(info, 150994995)
        return calls

    def test_keeps_the_other_keys(self):
        self.assertEqual(self.released(self.CLOSE), [
            ("setForeignShortcut", "asai", "4", "kwin", "Window Close", "KWin", "Close Window", "1", "42"),
        ])

    def test_names_a_non_default_context(self):
        info = list(self.CLOSE)
        info[4] = "plasmashell"
        self.assertEqual(self.released(info)[0][3], "kwin|plasmashell")


class ConflictTest(unittest.TestCase):
    def run_set(self, *extra):
        out = io.StringIO()
        with mock.patch.object(sc, "set_action") as set_action, \
                mock.patch.object(sc, "list_actions", lambda error=None, conflict=None: {"error": error, "conflict": conflict}), \
                mock.patch("sys.stdout", out):
            set_action.return_value = ("Alt+F4 is already used by KWin: Close Window", True)
            self.assertEqual(sc.main(["shortcuts.py", "set", "launcher.toggle", "150994995", *extra]), 0)
        return set_action, json.loads(out.getvalue())

    def test_conflict_is_reported(self):
        set_action, result = self.run_set()
        set_action.assert_called_once_with("launcher.toggle", 150994995, False)
        self.assertEqual(result["conflict"], {"id": "launcher.toggle", "code": 150994995})

    def test_force_is_passed_on(self):
        set_action, _result = self.run_set("--force")
        set_action.assert_called_once_with("launcher.toggle", 150994995, True)

    def test_unknown_flag_rejected(self):
        with mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(sc.main(["shortcuts.py", "set", "launcher.toggle", "1", "--nope"]), 2)


if __name__ == "__main__":
    unittest.main()
