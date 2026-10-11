"""Tests for the pure helpers in scripts/kdeconnect.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import kdeconnect  # noqa: E402

DEV = "abc_123"
BASE = f"/modules/kdeconnect/devices/{DEV}"


class PluginsInTreeTest(unittest.TestCase):
    def test_only_this_devices_direct_children(self):
        paths = [
            BASE, BASE + "/ping", BASE + "/share",
            BASE + "/share/extra",
            "/modules/kdeconnect/devices/other/battery",
            "/modules/kdeconnect",
        ]
        self.assertEqual(kdeconnect.plugins_in_tree(paths, DEV), {"ping", "share"})

    def test_no_plugins(self):
        self.assertEqual(kdeconnect.plugins_in_tree([BASE], DEV), set())


class SummarizeDeviceTest(unittest.TestCase):
    def test_phone_with_battery(self):
        d = kdeconnect.summarize_device(
            DEV, {"name": "Pixel", "isReachable": True},
            {"ping", "battery", "share"}, {"hasBattery": True, "charge": 80, "isCharging": True},
        )
        self.assertTrue(d["reachable"])
        self.assertTrue(d["hasBattery"])
        self.assertEqual(d["charge"], 80)
        self.assertTrue(d["charging"])
        self.assertTrue(d["canPing"])
        self.assertTrue(d["canShare"])
        self.assertFalse(d["canClipboard"])

    def test_device_without_battery_reports_none(self):
        d = kdeconnect.summarize_device(
            DEV, {"name": "iPhone", "isReachable": True},
            {"battery"}, {"hasBattery": False, "charge": -1, "isCharging": False},
        )
        self.assertFalse(d["hasBattery"])
        self.assertEqual(d["charge"], -1)

    def test_unreachable_device_offers_nothing(self):
        d = kdeconnect.summarize_device(DEV, {"name": "Away", "isReachable": False}, set(), None)
        self.assertFalse(d["reachable"])
        self.assertFalse(d["canPing"])
        self.assertFalse(d["hasBattery"])


class ActionTest(unittest.TestCase):
    def test_bad_device_id_is_rejected(self):
        with self.assertRaises(kdeconnect.KdeConnectError):
            kdeconnect.run_action("ping", "../etc")


if __name__ == "__main__":
    unittest.main()
