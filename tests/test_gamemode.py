"""Tests for the pure helpers in scripts/gamemode.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import gamemode  # noqa: E402


class ParseGamesTest(unittest.TestCase):
    def test_no_games(self):
        self.assertEqual(gamemode.parse_games("a(io) 0\n"), [])

    def test_several_games(self):
        out = 'a(io) 2 1234 "/com/feralinteractive/GameMode/Games/1234" 56 "/com/feralinteractive/GameMode/Games/56"\n'
        self.assertEqual(gamemode.parse_games(out), [1234, 56])

    def test_ignores_other_paths(self):
        self.assertEqual(gamemode.parse_games('a(io) 1 9 "/org/other/Games/9"'), [])


class ProcessNameTest(unittest.TestCase):
    def test_own_process(self):
        self.assertTrue(gamemode.process_name(os.getpid()))

    def test_missing_process_falls_back_to_pid(self):
        self.assertEqual(gamemode.process_name(2 ** 22 + 12345), str(2 ** 22 + 12345))


if __name__ == "__main__":
    unittest.main()
