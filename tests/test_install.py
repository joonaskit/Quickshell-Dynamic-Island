"""Tests for install.sh: dry runs, uninstalling and the folders it refuses to touch.
They run in a temporary home and never install anything. Run with ./test.sh."""
import os
import subprocess
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
INSTALL = os.path.join(ROOT, "install.sh")


class InstallScriptTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = os.path.join(self.tmp.name, "home")
        self.prefix = os.path.join(self.home, ".config", "quickshell", "island")
        self.autostart = os.path.join(self.home, ".config", "autostart", "quickshell-island.desktop")
        self.link = os.path.join(self.home, ".local", "bin", "island-run")
        os.makedirs(self.home)

    def run_install(self, *args):
        env = dict(os.environ, HOME=self.home, XDG_CONFIG_HOME=os.path.join(self.home, ".config"))
        env.pop("XDG_BIN_HOME", None)
        return subprocess.run(["bash", INSTALL, *args], capture_output=True, text=True, env=env, timeout=60, stdin=subprocess.DEVNULL)

    def make_install(self, config=("settings.json", "dock_pinned.json")):
        """A folder that looks like an install, with a stub run.sh and some configuration."""
        os.makedirs(self.prefix)
        for name in ("shell.qml", "qmldir"):
            open(os.path.join(self.prefix, name), "w").close()
        run = os.path.join(self.prefix, "run.sh")
        with open(run, "w") as f:
            f.write("#!/bin/sh\nexit 0\n")
        os.chmod(run, 0o755)
        for name in config:
            with open(os.path.join(self.prefix, name), "w") as f:
                f.write("{}")
        os.makedirs(os.path.dirname(self.autostart))
        with open(self.autostart, "w") as f:
            f.write("[Desktop Entry]\n")

    def test_syntax(self):
        self.assertEqual(subprocess.run(["bash", "-n", INSTALL]).returncode, 0)

    def test_help(self):
        result = self.run_install("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--dry-run", result.stdout)

    def test_unknown_option_fails(self):
        result = self.run_install("--nonsense")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Unknown option", result.stderr)

    def test_dry_run_changes_nothing(self):
        self.run_install("--dry-run", "--yes")
        self.assertEqual(os.listdir(self.home), [])

    def test_dry_run_uninstall_changes_nothing(self):
        self.make_install()
        result = self.run_install("--uninstall", "--dry-run", "--yes")
        self.assertEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(os.path.join(self.prefix, "shell.qml")))
        self.assertTrue(os.path.exists(self.autostart))

    def test_dry_run_mentions_the_island_run_link(self):
        result = self.run_install("--dry-run", "--yes")
        self.assertIn("island-run", result.stdout)
        self.assertIn("island-run skipped", self.run_install("--dry-run", "--yes", "--no-link").stdout)

    def test_uninstall_removes_the_island_run_link(self):
        self.make_install()
        os.makedirs(os.path.dirname(self.link))
        os.symlink(os.path.join(self.prefix, "scripts", "island_run.py"), self.link)
        self.assertEqual(self.run_install("--uninstall", "--yes").returncode, 0)
        self.assertFalse(os.path.lexists(self.link))

    def test_uninstall_leaves_a_foreign_island_run_alone(self):
        self.make_install()
        os.makedirs(os.path.dirname(self.link))
        with open(self.link, "w") as f:
            f.write("mine")
        os.symlink("/usr/bin/true", self.link + "-other")
        self.assertEqual(self.run_install("--uninstall", "--yes").returncode, 0)
        self.assertTrue(os.path.exists(self.link))
        self.assertTrue(os.path.lexists(self.link + "-other"))

    def test_uninstall_keeps_the_configuration_by_default(self):
        self.make_install()
        result = self.run_install("--uninstall", "--yes")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(sorted(os.listdir(self.prefix)), ["dock_pinned.json", "settings.json"])
        self.assertFalse(os.path.exists(self.autostart))

    def test_uninstall_without_configuration_removes_the_folder(self):
        self.make_install(config=())
        self.assertEqual(self.run_install("--uninstall", "--yes").returncode, 0)
        self.assertFalse(os.path.exists(self.prefix))

    def test_uninstall_leaves_other_folders_alone(self):
        other = os.path.join(self.tmp.name, "other")
        os.makedirs(other)
        with open(os.path.join(other, "notes.txt"), "w") as f:
            f.write("mine")
        for target in (other, self.home, "/"):
            result = self.run_install("--uninstall", "--yes", "--prefix", target)
            self.assertEqual(result.returncode, 1, target)
        self.assertEqual(os.listdir(other), ["notes.txt"])

    def test_install_refuses_a_folder_that_is_not_an_install(self):
        other = os.path.join(self.tmp.name, "other")
        os.makedirs(other)
        with open(os.path.join(other, "notes.txt"), "w") as f:
            f.write("mine")
        result = self.run_install("--yes", "--no-deps", "--prefix", other)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(os.listdir(other), ["notes.txt"])

    def test_import_needs_an_existing_file(self):
        result = self.run_install("--yes", "--import", os.path.join(self.tmp.name, "missing.json"))
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
