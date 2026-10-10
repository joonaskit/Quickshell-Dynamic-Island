"""Tests for scripts/activities_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import activities_core as core  # noqa: E402


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


A = ":1.10"
B = ":1.11"


class FieldsTest(unittest.TestCase):
    def test_unknown_field_is_rejected(self):
        with self.assertRaises(core.ActivityError):
            core.validate_fields({"colour": "red"})

    def test_strings_are_capped_and_flattened(self):
        clean = core.validate_fields({"title": "x" * 500, "text": "a\nb\tc\x00d"})
        self.assertEqual(len(clean["title"]), core.MAX_TITLE)
        self.assertTrue(clean["title"].endswith("…"))
        self.assertEqual(clean["text"], "a b cd")

    def test_wrong_types_are_rejected(self):
        for fields in ({"title": 5}, {"progress": "half"}, {"progress": True}, {"actions": "cancel"}):
            with self.assertRaises(core.ActivityError, msg=str(fields)):
                core.validate_fields(fields)

    def test_progress(self):
        self.assertEqual(core.validate_fields({"progress": 0.25})["progress"], 0.25)
        self.assertEqual(core.validate_fields({"progress": 7})["progress"], 1.0)
        self.assertEqual(core.validate_fields({"progress": -0.5})["progress"], -1.0)
        with self.assertRaises(core.ActivityError):
            core.validate_fields({"progress": float("nan")})
        with self.assertRaises(core.ActivityError):
            core.validate_fields({"progress": float("inf")})

    def test_priority_and_state_must_be_known(self):
        self.assertEqual(core.validate_fields({"priority": "high", "state": "failed"}), {"priority": "high", "state": "failed"})
        with self.assertRaises(core.ActivityError):
            core.validate_fields({"priority": "urgent"})
        with self.assertRaises(core.ActivityError):
            core.validate_fields({"state": "finished"})

    def test_icon(self):
        self.assertEqual(core.validate_fields({"icon": "folder-copy"})["icon"], "folder-copy")
        self.assertEqual(core.validate_fields({"icon": "/usr/share/icons/a.svg"})["icon"], "/usr/share/icons/a.svg")
        self.assertEqual(core.validate_fields({"icon": ""})["icon"], "")
        for bad in ("../x.png", "/etc/../shadow.png", "/etc/passwd", "relative/a.png", "file:///a.png", "a b", "x" * 300):
            with self.assertRaises(core.ActivityError, msg=bad):
                core.validate_fields({"icon": bad})

    def test_actions(self):
        clean = core.validate_fields({"actions": [("cancel", "Cancel"), {"id": "open", "label": "Open"}]})
        self.assertEqual(clean["actions"], [{"id": "cancel", "label": "Cancel"}, {"id": "open", "label": "Open"}])
        for bad in ([("a", "A")] * 2, [("a", "A"), ("b", "B"), ("c", "C"), ("d", "D")], [("a",)], [("", "A")]):
            with self.assertRaises(core.ActivityError, msg=str(bad)):
                core.validate_fields({"actions": bad})

    def test_ids(self):
        core.validate_id("copy-1")
        for bad in ("", 5, "a/b", "x" * 100, "a\nb"):
            with self.assertRaises(core.ActivityError, msg=repr(bad)):
                core.validate_id(bad)


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.store = core.ActivityStore(self.clock)

    def test_show_applies_defaults(self):
        self.store.show(A, "c1", {"title": "Copying"})
        (item,) = self.store.snapshot()
        self.assertEqual(item["key"], f"{A}/c1")
        self.assertEqual((item["state"], item["priority"], item["progress"]), ("running", "normal", None))

    def test_update_merges_and_missing_is_not_found(self):
        self.store.show(A, "c1", {"title": "Copying", "text": "a.txt", "progress": 0.1})
        self.store.update(A, "c1", {"progress": 0.5})
        (item,) = self.store.snapshot()
        self.assertEqual((item["title"], item["text"], item["progress"]), ("Copying", "a.txt", 0.5))
        with self.assertRaises(core.ActivityError) as ctx:
            self.store.update(A, "nope", {"progress": 1})
        self.assertEqual(ctx.exception.code, "NotFound")

    def test_show_again_replaces_fields_but_keeps_position(self):
        self.store.show(A, "c1", {"title": "One", "text": "old"})
        self.store.show(A, "c2", {"title": "Two"})
        self.store.show(A, "c1", {"title": "One again"})
        keys = [i["key"] for i in self.store.snapshot()]
        self.assertEqual(keys, [f"{A}/c2", f"{A}/c1"])
        self.assertEqual(self.store.get_key(f"{A}/c1")["text"], "")

    def test_senders_do_not_share_ids(self):
        self.store.show(A, "c1", {"title": "A's"})
        self.store.show(B, "c1", {"title": "B's"})
        self.assertEqual(len(self.store.snapshot()), 2)
        self.store.dismiss(A, "c1")
        (item,) = self.store.snapshot()
        self.assertEqual(item["title"], "B's")

    def test_dismiss_missing_is_harmless(self):
        self.assertFalse(self.store.dismiss(A, "nope"))

    def test_limits(self):
        for n in range(core.MAX_PER_SENDER):
            self.store.show(A, f"c{n}", {})
        with self.assertRaises(core.ActivityError) as ctx:
            self.store.show(A, "one-too-many", {})
        self.assertEqual(ctx.exception.code, "LimitExceeded")
        # Replacing an existing one is not growth
        self.store.show(A, "c0", {"title": "again"})
        # Other senders are unaffected, up to the overall cap
        for sender in range(2, 6):
            for n in range(core.MAX_PER_SENDER):
                if len(self.store.snapshot()) >= core.MAX_TOTAL:
                    break
                self.store.show(f":1.{sender}", f"c{n}", {})
        with self.assertRaises(core.ActivityError):
            self.store.show(":1.99", "c", {})

    def test_rate_limit_is_per_sender_and_refills(self):
        for _ in range(core.RATE_BURST):
            self.store.show(A, "c1", {})
        with self.assertRaises(core.ActivityError) as ctx:
            self.store.show(A, "c1", {})
        self.assertEqual(ctx.exception.code, "RateLimited")
        self.store.show(B, "c1", {})
        self.clock.advance(1.0)
        self.store.show(A, "c1", {})

    def test_invalid_calls_do_not_change_state(self):
        self.store.show(A, "c1", {"title": "Copying", "progress": 0.2})
        with self.assertRaises(core.ActivityError):
            self.store.update(A, "c1", {"progress": 0.9, "priority": "bogus"})
        self.assertEqual(self.store.get_key(f"{A}/c1")["progress"], 0.2)


class LifecycleTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.store = core.ActivityStore(self.clock)

    def test_done_clears_itself_and_its_actions(self):
        self.store.show(A, "c1", {"actions": [("cancel", "Cancel")]})
        self.store.update(A, "c1", {"state": "done"})
        self.assertEqual(self.store.get_key(f"{A}/c1")["actions"], [])
        self.clock.advance(core.AUTO_DISMISS["done"] - 0.5)
        self.assertEqual(self.store.expire(), [])
        self.clock.advance(1.0)
        self.assertEqual(len(self.store.expire()), 1)
        self.assertEqual(self.store.snapshot(), [])

    def test_full_progress_alone_is_not_done(self):
        self.store.show(A, "c1", {"progress": 1.0})
        self.clock.advance(3600)
        self.assertEqual(self.store.expire(), [])
        self.assertEqual(self.store.snapshot()[0]["state"], "running")

    def test_cancelled_reports_final_text_then_clears(self):
        self.store.show(A, "c1", {"text": "5 of 12 files", "actions": [("cancel", "Cancel")]})
        self.store.update(A, "c1", {"state": "cancelled", "text": "Cancelled after 5 of 12 files"})
        self.assertEqual(self.store.snapshot()[0]["text"], "Cancelled after 5 of 12 files")
        self.clock.advance(core.AUTO_DISMISS["cancelled"] + 1)
        self.assertEqual(len(self.store.expire()), 1)

    def test_failed_stays_until_dismissed(self):
        self.store.show(A, "c1", {})
        self.store.update(A, "c1", {"state": "failed", "error": "report.pdf: permission denied"})
        self.clock.advance(86400)
        self.assertEqual(self.store.expire(), [])
        self.assertEqual(self.store.snapshot()[0]["error"], "report.pdf: permission denied")
        self.assertIsNotNone(self.store.dismiss_key(f"{A}/c1"))
        self.assertEqual(self.store.snapshot(), [])

    def test_finished_cannot_resume_but_can_be_shown_again(self):
        self.store.show(A, "c1", {})
        self.store.update(A, "c1", {"state": "failed"})
        with self.assertRaises(core.ActivityError) as ctx:
            self.store.update(A, "c1", {"state": "running"})
        self.assertEqual(ctx.exception.code, "InvalidState")
        self.store.show(A, "c1", {"title": "Retrying"})
        self.assertEqual(self.store.snapshot()[0]["state"], "running")

    def test_next_expiry(self):
        self.assertIsNone(self.store.next_expiry())
        self.store.show(A, "c1", {})
        self.assertIsNone(self.store.next_expiry())
        self.store.update(A, "c1", {"state": "done"})
        self.assertAlmostEqual(self.store.next_expiry(), core.AUTO_DISMISS["done"])

    def test_sender_gone_running_becomes_failed(self):
        self.store.show(A, "c1", {"title": "Copying", "progress": 0.6, "actions": [("cancel", "Cancel")]})
        self.assertTrue(self.store.sender_gone(A))
        (item,) = self.store.snapshot()
        self.assertEqual(item["state"], "failed")
        self.assertEqual(item["error"], core.ORPHANED_MESSAGE)
        self.assertEqual(item["actions"], [])
        self.assertTrue(item["orphaned"])
        # It does not clear itself: the user has not seen that it failed
        self.clock.advance(86400)
        self.assertEqual(self.store.expire(), [])
        self.assertEqual(self.store.senders(), set())

    def test_sender_gone_lets_finished_ones_run_out_and_keeps_failures(self):
        self.store.show(A, "done", {"state": "done"})
        self.store.show(A, "failed", {"state": "failed", "error": "disk full", "actions": [("retry", "Retry")]})
        self.store.show(B, "other", {})
        self.assertTrue(self.store.sender_gone(A))
        keys = {i["key"]: i for i in self.store.snapshot()}
        self.assertEqual(set(keys), {f"{A}/done", f"{A}/failed", f"{B}/other"})
        self.assertEqual(keys[f"{A}/failed"]["error"], "disk full")
        self.assertEqual(keys[f"{A}/failed"]["actions"], [])
        self.assertFalse(self.store.sender_gone(":1.404"))
        # A script that says "done" and exits still gets its moment on screen
        self.clock.advance(core.AUTO_DISMISS["done"] + 1)
        self.assertEqual([i["id"] for i in self.store.expire()], ["done"])
        self.assertEqual({i["id"] for i in self.store.snapshot()}, {"failed", "other"})

    def test_sender_gone_resets_its_rate_limit(self):
        for _ in range(core.RATE_BURST):
            self.store.show(A, "c1", {})
        self.store.sender_gone(A)
        self.store.show(A, "c1", {})


class OrderingTest(unittest.TestCase):
    def setUp(self):
        self.store = core.ActivityStore(Clock())

    def order(self):
        return [i["id"] for i in self.store.snapshot()]

    def test_newest_first_at_equal_priority(self):
        for name in ("a", "b", "c"):
            self.store.show(A, name, {})
        self.assertEqual(self.order(), ["c", "b", "a"])

    def test_updating_does_not_reshuffle(self):
        self.store.show(A, "a", {})
        self.store.show(A, "b", {})
        self.store.update(A, "a", {"progress": 0.5})
        self.assertEqual(self.order(), ["b", "a"])

    def test_priority_beats_recency(self):
        self.store.show(A, "important", {"priority": "high"})
        self.store.show(A, "newer", {})
        self.store.show(A, "background", {"priority": "low"})
        self.assertEqual(self.order(), ["important", "newer", "background"])

    def test_failed_beats_everything(self):
        self.store.show(A, "broken", {})
        self.store.show(A, "urgent", {"priority": "high"})
        self.store.update(A, "broken", {"state": "failed"})
        self.assertEqual(self.order(), ["broken", "urgent"])


if __name__ == "__main__":
    unittest.main()
