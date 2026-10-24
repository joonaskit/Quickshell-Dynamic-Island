"""Checks that qmldir registers every QML file of the shell, under its own name, as a singleton
exactly when the file has `pragma Singleton`, and that every entry's file exists.
Run with ./test.sh."""
import os
import re
import subprocess
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
QMLDIR = os.path.join(ROOT, "qmldir")

# Files that are not types: the entry point, and the tests, which qmltestrunner loads itself
NOT_REGISTERED = {"shell.qml"}
NOT_REGISTERED_DIRS = ("tests/",)


def parse_qmldir(text):
    """(name, path, singleton) for each type entry."""
    entries = []
    for line in text.splitlines():
        parts = line.split()
        if not parts or parts[0].startswith("#"):
            continue
        singleton = parts[0] == "singleton"
        if singleton:
            parts = parts[1:]
        if len(parts) == 3 and parts[2].endswith(".qml"):
            entries.append((parts[0], parts[2], singleton))
    return entries


def problems(entries, files):
    """One line per mistake, empty when qmldir and the files agree.
    files maps each QML path to whether it has `pragma Singleton`."""
    found = []
    seen = {}
    for name, path, singleton in entries:
        if name in seen:
            found.append("%s: registered twice (%s and %s)" % (name, seen[name], path))
        seen[name] = path
        if path not in files:
            found.append("%s: %s does not exist" % (name, path))
            continue
        stem = os.path.splitext(os.path.basename(path))[0]
        if name != stem:
            found.append("%s: registered under a different name than its file %s" % (name, path))
        if singleton and not files[path]:
            found.append("%s: registered as a singleton but %s has no pragma Singleton" % (name, path))
        if not singleton and files[path]:
            found.append("%s: %s has pragma Singleton but is not registered with singleton" % (name, path))
    registered = {path for _, path, _ in entries}
    for path in sorted(files):
        if path in registered or path in NOT_REGISTERED or path.startswith(NOT_REGISTERED_DIRS):
            continue
        found.append("%s: not registered in qmldir" % path)
    return found


def shell_files():
    """Tracked and untracked (not ignored) QML files, as lint.sh lints them, mapped to
    whether each has `pragma Singleton`."""
    out = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "*.qml"],
        cwd=ROOT, check=True, capture_output=True, text=True).stdout
    files = {}
    for path in out.split("\0"):
        full = os.path.join(ROOT, path)
        if path and os.path.isfile(full):
            with open(full, encoding="utf-8") as f:
                files[path] = re.search(r"^\s*pragma\s+Singleton\b", f.read(), re.M) is not None
    return files


class QmldirTest(unittest.TestCase):
    def setUp(self):
        with open(QMLDIR, encoding="utf-8") as f:
            self.entries = parse_qmldir(f.read())
        self.files = shell_files()

    def test_qmldir_matches_files(self):
        self.assertEqual(problems(self.entries, self.files), [])

    def test_unregistered_file(self):
        files = dict(self.files, **{"island/NewPill.qml": False})
        self.assertEqual(problems(self.entries, files), ["island/NewPill.qml: not registered in qmldir"])

    def test_missing_file(self):
        files = {p: s for p, s in self.files.items() if p != "components/SvgIcon.qml"}
        self.assertEqual(problems(self.entries, files), ["SvgIcon: components/SvgIcon.qml does not exist"])

    def test_wrong_name(self):
        entries = [("Icon" if n == "SvgIcon" else n, p, s) for n, p, s in self.entries]
        self.assertEqual(problems(entries, self.files),
                         ["Icon: registered under a different name than its file components/SvgIcon.qml"])

    def test_singleton_without_keyword(self):
        entries = [(n, p, False if n == "Theme" else s) for n, p, s in self.entries]
        self.assertEqual(problems(entries, self.files),
                         ["Theme: services/Theme.qml has pragma Singleton but is not registered with singleton"])

    def test_keyword_without_pragma(self):
        entries = [(n, p, True if n == "SvgIcon" else s) for n, p, s in self.entries]
        self.assertEqual(problems(entries, self.files),
                         ["SvgIcon: registered as a singleton but components/SvgIcon.qml has no pragma Singleton"])

    def test_registered_twice(self):
        entries = self.entries + [("SvgIcon", "components/SvgIcon.qml", False)]
        self.assertEqual(problems(entries, self.files),
                         ["SvgIcon: registered twice (components/SvgIcon.qml and components/SvgIcon.qml)"])

    def test_parse_qmldir(self):
        text = "singleton Theme 1.0 services/Theme.qml\n\n# a comment\nSvgIcon 1.0 components/SvgIcon.qml\n"
        self.assertEqual(parse_qmldir(text), [("Theme", "services/Theme.qml", True),
                                              ("SvgIcon", "components/SvgIcon.qml", False)])


if __name__ == "__main__":
    unittest.main()
