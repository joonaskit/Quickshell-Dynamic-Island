"""Tests for scripts/check_deps.py with a fake system, and for deps.json itself. Run with ./test.sh."""
import json
import os
import sys
import unittest

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "scripts"))

import check_deps  # noqa: E402


class FakeProbe:
    def __init__(self, commands=(), modules=(), session="wayland", names=None, units=()):
        self.commands = set(commands)
        self.modules = set(modules)
        self.session = session
        self.names = names or {}
        self.units = set(units)

    def has_command(self, name):
        return name in self.commands

    def has_module(self, name):
        return name in self.modules

    def session_type(self):
        return self.session

    def bus_names(self, bus):
        return set(self.names.get(bus, ()))

    def has_unit(self, unit, bus):
        return (bus, unit) in self.units


def dep(check, severity="optional", packages=None, dep_id="x"):
    return {"id": dep_id, "name": dep_id, "severity": severity, "check": check,
            "features": ["a feature"], "packages": packages or {}}


class CheckStatusTest(unittest.TestCase):
    def test_any_of_needs_one_command(self):
        check = {"type": "command", "anyOf": ["kdialog", "zenity"]}
        self.assertEqual(check_deps.check_status(check, FakeProbe(commands=["zenity"])), "found")
        self.assertEqual(check_deps.check_status(check, FakeProbe()), "missing")

    def test_all_of_needs_every_command(self):
        check = {"type": "command", "allOf": ["wl-paste", "wl-copy"]}
        self.assertEqual(check_deps.check_status(check, FakeProbe(commands=["wl-paste", "wl-copy"])), "found")
        self.assertEqual(check_deps.check_status(check, FakeProbe(commands=["wl-paste"])), "missing")

    def test_python_module(self):
        check = {"type": "python", "module": "dbus"}
        self.assertEqual(check_deps.check_status(check, FakeProbe(modules=["dbus"])), "found")
        self.assertEqual(check_deps.check_status(check, FakeProbe()), "missing")

    def test_session(self):
        check = {"type": "session", "value": "wayland"}
        self.assertEqual(check_deps.check_status(check, FakeProbe(session="wayland")), "found")
        self.assertEqual(check_deps.check_status(check, FakeProbe(session="x11")), "missing")

    def test_dbus_name_on_the_bus(self):
        check = {"type": "dbus", "bus": "system", "name": "org.freedesktop.UPower", "units": ["upower.service"]}
        probe = FakeProbe(names={"system": ["org.freedesktop.UPower"]})
        self.assertEqual(check_deps.check_status(check, probe), "found")

    def test_dbus_name_on_the_wrong_bus_is_not_found(self):
        check = {"type": "dbus", "bus": "system", "name": "org.freedesktop.UPower"}
        probe = FakeProbe(names={"user": ["org.freedesktop.UPower"]})
        self.assertEqual(check_deps.check_status(check, probe), "missing")

    def test_dbus_installed_unit_is_not_running(self):
        check = {"type": "dbus", "bus": "system", "name": "org.freedesktop.UPower", "units": ["upower.service"]}
        probe = FakeProbe(units=[("system", "upower.service")])
        self.assertEqual(check_deps.check_status(check, probe), "not-running")

    def test_dbus_installed_command_is_not_running(self):
        check = {"type": "dbus", "bus": "user", "name": "org.kde.kdeconnect", "commands": ["kdeconnectd"]}
        self.assertEqual(check_deps.check_status(check, FakeProbe(commands=["kdeconnectd"])), "not-running")
        self.assertEqual(check_deps.check_status(check, FakeProbe()), "missing")

    def test_unknown_type_is_an_error(self):
        with self.assertRaises(ValueError):
            check_deps.check_status({"type": "magic"}, FakeProbe())


class DetectDistroTest(unittest.TestCase):
    def test_by_id(self):
        self.assertEqual(check_deps.detect_distro('NAME="Fedora Linux"\nID=fedora\n'), "fedora")
        self.assertEqual(check_deps.detect_distro("ID=arch\n"), "arch")
        self.assertEqual(check_deps.detect_distro('ID="opensuse-tumbleweed"\nID_LIKE="opensuse suse"\n'), "opensuse")

    def test_by_id_like(self):
        self.assertEqual(check_deps.detect_distro("ID=ubuntu\nID_LIKE=debian\n"), "debian")
        self.assertEqual(check_deps.detect_distro("ID=cachyos\nID_LIKE=arch\n"), "arch")
        self.assertEqual(check_deps.detect_distro('ID=nobara\nID_LIKE="rhel centos fedora"\n'), "fedora")

    def test_unknown(self):
        self.assertEqual(check_deps.detect_distro("ID=nixos\n"), "")
        self.assertEqual(check_deps.detect_distro(""), "")


class EvaluateTest(unittest.TestCase):
    def manifest(self):
        return {"dependencies": [
            dep({"type": "command", "anyOf": ["quickshell"]}, "required", {"fedora": "quickshell"}, "quickshell"),
            dep({"type": "command", "anyOf": ["busctl"]}, "recommended", {"fedora": "systemd"}, "busctl"),
            dep({"type": "command", "anyOf": ["loginctl"]}, "recommended", {"fedora": "systemd"}, "loginctl"),
            dep({"type": "command", "anyOf": ["nmcli"]}, "optional", {"arch": "networkmanager"}, "nmcli"),
        ]}

    def test_all_found(self):
        probe = FakeProbe(commands=["quickshell", "busctl", "loginctl", "nmcli"])
        report = check_deps.evaluate(self.manifest(), probe, "fedora")
        self.assertTrue(report["ok"])
        self.assertEqual(report["installCommand"], "")
        self.assertEqual([r["status"] for r in report["dependencies"]], ["found"] * 4)

    def test_only_a_required_one_fails_the_check(self):
        report = check_deps.evaluate(self.manifest(), FakeProbe(commands=["quickshell"]), "fedora")
        self.assertTrue(report["ok"])
        report = check_deps.evaluate(self.manifest(), FakeProbe(commands=["busctl"]), "fedora")
        self.assertFalse(report["ok"])

    def test_install_command_lists_each_package_once(self):
        report = check_deps.evaluate(self.manifest(), FakeProbe(), "fedora")
        self.assertEqual(report["installCommand"], "sudo dnf install quickshell systemd")

    def test_no_install_command_without_a_known_distro(self):
        report = check_deps.evaluate(self.manifest(), FakeProbe(), "")
        self.assertEqual(report["installCommand"], "")
        self.assertEqual(report["dependencies"][0]["package"], "")

    def test_services_that_are_not_running_are_not_installed_again(self):
        manifest = {"dependencies": [dep({"type": "dbus", "bus": "system", "name": "a.b", "units": ["a.service"]},
                                         "optional", {"fedora": "a"})]}
        report = check_deps.evaluate(manifest, FakeProbe(units=[("system", "a.service")]), "fedora")
        self.assertEqual(report["dependencies"][0]["status"], "not-running")
        self.assertEqual(report["installCommand"], "")

    def test_unknown_severity_is_an_error(self):
        with self.assertRaises(ValueError):
            check_deps.evaluate({"dependencies": [dep({"type": "command", "anyOf": ["a"]}, "vital")]}, FakeProbe(), "")

    def test_table_names_what_is_affected(self):
        table = check_deps.format_table(check_deps.evaluate(self.manifest(), FakeProbe(), "fedora"))
        self.assertIn("affects: a feature", table)
        self.assertIn("1 of them required", table)
        self.assertIn("sudo dnf install quickshell systemd", table)


class ManifestTest(unittest.TestCase):
    """deps.json must be something the check can evaluate on any system."""

    def setUp(self):
        with open(os.path.join(ROOT, "deps.json")) as f:
            self.manifest = json.load(f)

    def test_evaluates_on_an_empty_system(self):
        report = check_deps.evaluate(self.manifest, FakeProbe(session=""), "fedora")
        self.assertFalse(report["ok"])
        self.assertTrue(all(r["status"] == "missing" for r in report["dependencies"]))

    def test_ids_are_unique_and_entries_complete(self):
        ids = [d["id"] for d in self.manifest["dependencies"]]
        self.assertEqual(len(ids), len(set(ids)))
        for d in self.manifest["dependencies"]:
            self.assertTrue(d["name"] and d["features"], d["id"])
            self.assertLessEqual(set(d["packages"]), set(self.manifest["distros"]), d["id"])

    def test_distros_have_an_install_command(self):
        self.assertEqual(set(self.manifest["distros"]), set(check_deps.INSTALL_COMMANDS))


if __name__ == "__main__":
    unittest.main()
