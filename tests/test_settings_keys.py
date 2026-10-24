"""Checks that every setting in settings.json.example is declared, loaded, reset and saved
by services/SettingsService.qml, and that every saved key has a default in the example.
Run with ./test.sh."""
import json
import os
import re
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SERVICE = os.path.join(ROOT, "services", "SettingsService.qml")
EXAMPLE = os.path.join(ROOT, "settings.json.example")

# Keys handled differently on purpose, by the check they skip
# Loaded by SettingsMigration.widgetStates, which also reads the per-widget keys of older configs
NOT_READ_DIRECTLY = {"widgets"}
# Resetting the settings must not show the welcome guide again
NOT_RESET = {"onboardingVersion"}


def function_body(text, name):
    """The text between the braces of `function name(...) { ... }`, or "" if there is none."""
    m = re.search(r"function %s\([^)]*\)\s*\{" % re.escape(name), text)
    if not m:
        return ""
    depth, i = 1, m.end()
    while depth and i < len(text):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[m.end():i - 1]


def assigns(body, key):
    return re.search(r"\broot\.%s\s*=(?!=)" % re.escape(key), body) is not None


def problems(qml, example_keys):
    """One line per missing edit, empty when every key is handled in all five places."""
    load = function_body(qml, "applySettings")
    reset = function_body(qml, "resetDefaults")
    saved = set(re.findall(r'"(\w+)"\s*:', function_body(qml, "saveSettings")))
    found = []
    for key in example_keys:
        if not re.search(r"^\s*property\s+\w+\s+%s\s*:" % re.escape(key), qml, re.M):
            found.append("%s: no property in SettingsService.qml" % key)
        if not assigns(load, key) or (key not in NOT_READ_DIRECTLY and not re.search(r"\bdata\.%s\b" % re.escape(key), load)):
            found.append("%s: not loaded in applySettings" % key)
        if key not in NOT_RESET and not assigns(reset, key):
            found.append("%s: not reset in resetDefaults" % key)
        if key not in saved:
            found.append("%s: not saved in saveSettings" % key)
    for key in sorted(saved - set(example_keys)):
        found.append("%s: saved but has no default in settings.json.example" % key)
    return found


def read_files():
    with open(SERVICE, encoding="utf-8") as f:
        qml = f.read()
    with open(EXAMPLE, encoding="utf-8") as f:
        keys = list(json.load(f))
    return qml, keys


class SettingsKeysTest(unittest.TestCase):
    def setUp(self):
        self.qml, self.keys = read_files()

    def test_every_key_is_handled(self):
        self.assertEqual(problems(self.qml, self.keys), [])

    def without_line(self, pattern):
        """The service with the one line matching `pattern` removed."""
        qml, n = re.subn(r"^.*%s.*\n" % pattern, "", self.qml, count=1, flags=re.M)
        self.assertEqual(n, 1, pattern)
        return qml

    def test_missing_property(self):
        qml = self.without_line(r"property bool showOsd:")
        self.assertIn("showOsd: no property in SettingsService.qml", problems(qml, self.keys))

    def test_missing_load(self):
        qml = self.without_line(r"if \(data\.showOsd !== undefined\)")
        self.assertIn("showOsd: not loaded in applySettings", problems(qml, self.keys))

    def test_missing_reset(self):
        qml = self.without_line(r"root\.showOsd = true;")
        self.assertIn("showOsd: not reset in resetDefaults", problems(qml, self.keys))

    def test_missing_save(self):
        qml = self.without_line(r'"showOsd": root\.showOsd')
        self.assertIn("showOsd: not saved in saveSettings", problems(qml, self.keys))

    def test_missing_example_default(self):
        keys = [k for k in self.keys if k != "showOsd"]
        self.assertEqual(problems(self.qml, keys), ["showOsd: saved but has no default in settings.json.example"])

    def test_new_example_key_without_code(self):
        found = problems(self.qml, self.keys + ["brandNewSetting"])
        self.assertEqual(len([p for p in found if p.startswith("brandNewSetting:")]), 4)

    def test_function_body_matches_nested_braces(self):
        self.assertEqual(function_body("function f(a) { if (a) { x } } y", "f"), " if (a) { x } ")


if __name__ == "__main__":
    unittest.main()
