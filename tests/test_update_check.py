"""Tests for scripts/update_check.py on temporary git repositories: an upstream,
and a clone of it standing in for the installed shell. Run with ./test.sh."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import unittest.mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import update_check as upd  # noqa: E402

ENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
           GIT_COMMITTER_EMAIL="t@t", GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")


def git(directory, *args):
    return subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True,
                          env=ENV, check=True).stdout.strip()


@unittest.skipUnless(shutil.which("git"), "git is not installed")
class UpdateCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        # The tests' git config must reach the script's own git calls too
        self.enterContext(unittest.mock.patch.dict(upd.GIT_ENV, ENV))
        self.upstream = os.path.join(self.tmp, "upstream")
        os.mkdir(self.upstream)
        git(self.upstream, "init", "--quiet", "--initial-branch=main")
        self.commit(self.upstream, "First")
        git(self.upstream, "tag", "-a", "-m", "release", "v0.1.0")
        self.shell = os.path.join(self.tmp, "shell")
        git(self.tmp, "clone", "--quiet", self.upstream, self.shell)

    def commit(self, directory, message):
        with open(os.path.join(directory, "file.txt"), "a", encoding="utf-8") as f:
            f.write(message + "\n")
        git(directory, "add", "file.txt")
        git(directory, "commit", "--quiet", "-m", message)

    def test_up_to_date(self):
        for channel in ("stable", "beta"):
            result = upd.check(self.shell, channel)
            self.assertEqual(result["state"], "up-to-date", channel)
            self.assertEqual(result["current"], "v0.1.0")

    def test_stable_ignores_commits_without_a_release(self):
        self.commit(self.upstream, "Unreleased")
        self.assertEqual(upd.check(self.shell, "stable")["state"], "up-to-date")
        result = upd.check(self.shell, "beta")
        self.assertEqual((result["state"], result["behind"], result["commits"]), ("available", 1, ["Unreleased"]))

    def test_stable_updates_to_the_newest_release_only(self):
        self.commit(self.upstream, "Fix")
        git(self.upstream, "tag", "-a", "-m", "release", "v0.2.0-beta.1")
        self.commit(self.upstream, "After the release")
        result = upd.check(self.shell, "stable")
        self.assertEqual((result["state"], result["target"], result["behind"]), ("available", "v0.2.0-beta.1", 1))
        result = upd.update(self.shell, "stable")
        self.assertEqual((result["state"], result["previous"], result["current"]), ("updated", "v0.1.0", "v0.2.0-beta.1"))
        # Still on main, so beta can carry on from here
        self.assertEqual(git(self.shell, "branch", "--show-current"), "main")
        self.assertEqual(upd.check(self.shell, "beta")["behind"], 1)

    def test_beta_updates_to_the_newest_commit(self):
        self.commit(self.upstream, "One")
        self.commit(self.upstream, "Two")
        result = upd.update(self.shell, "beta")
        self.assertEqual(result["state"], "updated")
        self.assertEqual(git(self.shell, "rev-parse", "HEAD"), git(self.upstream, "rev-parse", "HEAD"))
        self.assertEqual(upd.check(self.shell, "beta")["state"], "up-to-date")

    def test_local_changes_block_the_update(self):
        self.commit(self.upstream, "Upstream")
        with open(os.path.join(self.shell, "file.txt"), "a", encoding="utf-8") as f:
            f.write("edited\n")
        result = upd.update(self.shell, "beta")
        self.assertEqual((result["state"], result["canUpdate"]), ("local-changes", False))
        with open(os.path.join(self.shell, "file.txt"), encoding="utf-8") as f:
            self.assertIn("edited", f.read())

    def test_another_branch_is_left_alone(self):
        self.commit(self.upstream, "Upstream")
        git(self.shell, "switch", "--quiet", "-c", "dev")
        before = git(self.shell, "rev-parse", "HEAD")
        self.assertEqual(upd.update(self.shell, "beta")["state"], "other-branch")
        self.assertEqual(git(self.shell, "rev-parse", "HEAD"), before)

    def test_diverged(self):
        self.commit(self.upstream, "Upstream")
        self.commit(self.shell, "Local")
        self.assertEqual(upd.check(self.shell, "beta")["state"], "diverged")

    def test_no_release_tag(self):
        git(self.shell, "tag", "-d", "v0.1.0")
        git(self.upstream, "tag", "-d", "v0.1.0")
        self.assertEqual(upd.check(self.shell, "stable")["state"], "no-target")

    def test_offline(self):
        git(self.shell, "remote", "set-url", "origin", os.path.join(self.tmp, "missing"))
        result = upd.check(self.shell, "beta")
        self.assertEqual((result["ok"], result["state"]), (False, "offline"))
        self.assertNotEqual(result["error"], "")

    def test_a_folder_inside_another_checkout_is_not_one(self):
        inner = os.path.join(self.shell, "copied-shell")
        os.mkdir(inner)
        self.assertEqual(upd.check(inner, "beta")["state"], "not-git")
        self.assertEqual(upd.check(self.tmp, "beta")["state"], "not-git")


if __name__ == "__main__":
    unittest.main()
