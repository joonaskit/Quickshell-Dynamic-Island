"""Tests for scripts/update_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import update_core as uc  # noqa: E402


class VersionTest(unittest.TestCase):
    def test_pre_releases_sort_before_the_release(self):
        tags = ["v0.1.0", "v0.1.0-rc.1", "v0.1.0-alpha.2", "v0.1.0-beta.1", "v0.1.0-alpha.10"]
        self.assertEqual(sorted(tags, key=uc.version_key),
                         ["v0.1.0-alpha.2", "v0.1.0-alpha.10", "v0.1.0-beta.1", "v0.1.0-rc.1", "v0.1.0"])

    def test_numbers_compare_as_numbers(self):
        self.assertEqual(uc.latest_release(["v0.9.0", "v0.10.0", "v0.2.0"]), "v0.10.0")

    def test_other_tags_are_not_releases(self):
        for tag in ["0.1.0", "v1.2", "v1.2.3-dev", "v1.2.3-beta", "latest", "v1.2.3.4"]:
            self.assertIsNone(uc.version_key(tag), tag)
        self.assertEqual(uc.latest_release(["latest", "v0.1.0-beta.1", "nightly"]), "v0.1.0-beta.1")

    def test_no_release(self):
        self.assertIsNone(uc.latest_release([]))
        self.assertIsNone(uc.latest_release(["latest"]))


class DecideTest(unittest.TestCase):
    def test_states(self):
        cases = [
            (("main", False, 3, 0), ("available", True)),
            (("main", False, 0, 0), ("up-to-date", False)),
            # Newer than the latest release is up to date, not a downgrade
            (("main", False, 0, 5), ("up-to-date", False)),
            (("main", False, 2, 1), ("diverged", False)),
            (("main", True, 2, 0), ("local-changes", False)),
            # Edits with nothing to update are no problem
            (("main", True, 0, 0), ("up-to-date", False)),
            (("dev", False, 3, 0), ("other-branch", False)),
            # Detached HEAD has no branch name
            (("", False, 3, 0), ("other-branch", False)),
        ]
        for args, expected in cases:
            self.assertEqual(uc.decide(*args), expected, args)


if __name__ == "__main__":
    unittest.main()
