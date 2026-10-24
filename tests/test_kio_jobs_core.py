"""Tests for scripts/kio_jobs_core.py. Run with ./test.sh."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import kio_jobs_core as core  # noqa: E402

# What Dolphin sends for a copy of a folder, as seen on the bus
COPY = {
    "title": "Copying",
    "descriptionLabel1": "Source",
    "descriptionValue1": "/home/me/src/many/f18138.txt",
    "descriptionLabel2": "Destination",
    "descriptionValue2": "/home/me/dst/many/f18138.txt",
    "destUrl": "file:///home/me/dst/",
    "elapsedTime": 379,
    "immediate": True,
    "percent": 9,
    "processedBytes": 3722000,
    "totalBytes": 40000000,
    "processedFiles": 1862,
    "totalFiles": 20000,
}

ONE_FILE = {
    "title": "Copying",
    "descriptionValue1": "/home/me/Videos/holiday%20clip.mp4",
    "percent": 40,
    "totalBytes": 1000,
    "totalFiles": 1,
}


class FormatTest(unittest.TestCase):
    def test_speed(self):
        self.assertEqual(core.format_speed(15072000), "14.4 MiB/s")

    def test_small_speed(self):
        self.assertEqual(core.format_speed(512), "512 B/s")

    def test_file_name_of_path(self):
        self.assertEqual(core.file_name("/home/me/a/b.txt"), "b.txt")

    def test_file_name_of_url(self):
        self.assertEqual(core.file_name("sftp://host/srv/My%20File.txt"), "My File.txt")

    def test_file_name_of_folder(self):
        self.assertEqual(core.file_name("/home/me/Photos/"), "Photos")


class FieldsTest(unittest.TestCase):
    def test_title_counts_files(self):
        self.assertEqual(core.title_for(COPY), "Copying 20,000 files")

    def test_title_names_a_single_file(self):
        self.assertEqual(core.title_for(ONE_FILE), "Copying holiday%20clip.mp4")

    def test_title_without_anything(self):
        self.assertEqual(core.title_for({}), "Working")

    def test_text_is_current_file_and_speed(self):
        self.assertEqual(core.text_for(dict(COPY, speed=15072000)), "f18138.txt · 14.4 MiB/s")

    def test_text_leaves_out_the_name_already_in_the_title(self):
        self.assertEqual(core.text_for(dict(ONE_FILE, speed=2048)), "2.0 KiB/s")

    def test_text_falls_back_to_info_message(self):
        self.assertEqual(core.text_for({"infoMessage": "Examining"}), "Examining")

    def test_progress(self):
        self.assertAlmostEqual(core.progress_for(COPY), 0.09)

    def test_progress_unknown_total_is_indeterminate(self):
        self.assertEqual(core.progress_for({"percent": 0}), -1.0)

    def test_progress_missing_is_indeterminate(self):
        self.assertEqual(core.progress_for({"title": "Copying"}), -1.0)

    def test_progress_is_clamped(self):
        self.assertEqual(core.progress_for({"percent": 140, "totalBytes": 1}), 1.0)


class EndTest(unittest.TestCase):
    def test_success_is_done(self):
        self.assertEqual(core.end_fields(COPY, 0, "")["state"], "done")

    def test_killed_is_cancelled_with_how_far_it_got(self):
        fields = core.end_fields(dict(COPY, processedFiles=8504), core.KILLED, "")
        self.assertEqual(fields, {"state": "cancelled", "text": "Cancelled after 8,504 of 20,000 files"})

    def test_killed_single_file(self):
        self.assertEqual(core.end_fields(ONE_FILE, core.KILLED, "")["text"], "Cancelled")

    def test_error_is_failed_with_message_and_no_cancel(self):
        fields = core.end_fields(COPY, 113, "Access denied to /mnt/x.")
        self.assertEqual(fields, {"state": "failed", "error": "Access denied to /mnt/x.", "actions": []})

    def test_error_without_message(self):
        self.assertEqual(core.end_fields(COPY, 113, "  ")["error"], "Failed (error 113)")


class ShowDelayTest(unittest.TestCase):
    def test_counts_the_time_kio_already_waited(self):
        self.assertEqual(core.show_delay_ms({"elapsedTime": 379}), 621)

    def test_long_running_job_shows_at_once(self):
        self.assertEqual(core.show_delay_ms({"elapsedTime": 5000}), 0)

    def test_no_elapsed_time(self):
        self.assertEqual(core.show_delay_ms({}), core.SHOW_AFTER_MS)


class JobsTest(unittest.TestCase):
    def setUp(self):
        self.jobs = core.Jobs()

    def add(self, now=0, owner=":1.5", capabilities=3, props=None):
        return self.jobs.add(owner, "system-file-manager", capabilities, dict(props or COPY, elapsedTime=0), now)

    def test_nothing_before_a_second(self):
        self.add()
        self.assertEqual(self.jobs.take_calls(999, 10), [])

    def test_shown_after_a_second(self):
        job = self.add()
        calls = self.jobs.take_calls(1000, 10)
        self.assertEqual(len(calls), 1)
        method, activity_id, fields = calls[0]
        self.assertEqual((method, activity_id), ("Show", job.id))
        self.assertEqual(fields["title"], "Copying 20,000 files")
        self.assertEqual(fields["icon"], "system-file-manager")
        self.assertEqual(fields["actions"], [core.CANCEL_ACTION])

    def test_no_cancel_for_a_job_that_cannot_be_killed(self):
        self.add(capabilities=0)
        self.assertNotIn("actions", self.jobs.take_calls(1000, 10)[0][2])

    def test_job_that_ends_early_is_never_shown(self):
        job = self.add()
        self.jobs.terminate(job.number, 0, "")
        self.assertEqual(self.jobs.take_calls(5000, 10), [])
        self.assertEqual(self.jobs.jobs, {})

    def test_update_sends_only_what_changed(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.update(job.number, {"percent": 50})
        self.assertEqual(self.jobs.take_calls(1250, 10), [("Update", job.id, {"progress": 0.5})])
        self.assertEqual(self.jobs.take_calls(1500, 10), [])

    def test_done(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.terminate(job.number, 0, "")
        calls = self.jobs.take_calls(1250, 10)
        self.assertEqual(calls[0][2]["state"], "done")
        self.jobs.take_calls(1500, 10)
        self.assertEqual(self.jobs.jobs, {})

    def test_failed_final_update_is_sent_again(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.terminate(job.number, 113, "Access denied")
        self.jobs.take_calls(1250, 10)
        self.jobs.call_failed(job.id, "Update", "RateLimited")
        calls = self.jobs.take_calls(1500, 10)
        self.assertEqual(calls[0][2]["state"], "failed")
        self.assertEqual(calls[0][2]["error"], "Access denied")

    def test_cancel_keeps_running_until_kio_ends_it(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.assertIs(self.jobs.cancel_requested(job.id), job)
        self.assertEqual(self.jobs.take_calls(1250, 10), [])
        self.jobs.terminate(job.number, core.KILLED, "")
        self.assertEqual(self.jobs.take_calls(1500, 10)[0][2]["state"], "cancelled")

    def test_cancel_for_a_finished_job_does_nothing(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.terminate(job.number, 0, "")
        self.assertIsNone(self.jobs.cancel_requested(job.id))

    def test_app_that_closes_fails_its_shown_jobs(self):
        shown = self.add(owner=":1.5")
        self.jobs.take_calls(1000, 10)
        waiting = self.add(now=900, owner=":1.5")
        other = self.add(now=900, owner=":1.9")
        self.jobs.owner_gone(":1.5")
        self.assertEqual(self.jobs.get(shown.number).final["error"], core.APP_CLOSED)
        self.assertIsNone(self.jobs.get(waiting.number))
        self.assertIsNotNone(self.jobs.get(other.number))

    def test_dismissed_job_is_not_shown_again(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.dismissed(job.id)
        self.jobs.update(job.number, {"percent": 60})
        self.assertEqual(self.jobs.take_calls(1250, 10), [])
        self.jobs.terminate(job.number, 0, "")
        self.assertEqual(self.jobs.jobs, {})

    def test_not_found_hides_the_job(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.call_failed(job.id, "Update", "NotFound")
        self.jobs.update(job.number, {"percent": 60})
        self.assertEqual(self.jobs.take_calls(1250, 10), [])

    def test_refused_show_is_tried_again(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.call_failed(job.id, "Show", "LimitExceeded")
        self.assertEqual(self.jobs.take_calls(1250, 10)[0][0], "Show")

    def test_island_restart_shows_running_jobs_again(self):
        running = self.add()
        ended = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.terminate(ended.number, 0, "")
        self.jobs.island_restarted()
        self.assertEqual(self.jobs.take_calls(1250, 10), [("Show", running.id, running.show_fields())])
        self.assertIsNone(self.jobs.get(ended.number))

    def test_island_restart_keeps_dismissed_jobs_hidden(self):
        job = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.dismissed(job.id)
        self.jobs.island_restarted()
        self.assertEqual(self.jobs.take_calls(1250, 10), [])

    def test_budget_puts_endings_first(self):
        first = self.add()
        second = self.add()
        self.jobs.take_calls(1000, 10)
        self.jobs.update(first.number, {"percent": 50})
        self.jobs.terminate(second.number, 0, "")
        calls = self.jobs.take_calls(1250, 1)
        self.assertEqual(calls, [("Update", second.id, calls[0][2])])
        self.assertEqual(calls[0][2]["state"], "done")

    def test_next_due(self):
        self.add(now=0)
        self.add(now=400)
        self.assertEqual(self.jobs.next_due(200), 800)
        self.jobs.take_calls(1000, 10)
        self.assertEqual(self.jobs.next_due(1100), 300)


if __name__ == "__main__":
    unittest.main()
