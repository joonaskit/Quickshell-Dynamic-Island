"""End to end test of scripts/kio_jobs.py, on the private bus of ./run.sh --sandbox.

Three fake KIO jobs (examples/kio_job_client.py) run at once: one finishes,
one fails and one exits halfway. The sandbox's activities_bridge.py logs every
activity list it would send to the shell, and the last state of each activity
is checked. Skipped when dbus-run-session or the Python D-Bus modules are missing.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))

import kio_jobs_core  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

try:
    import dbus  # noqa: F401
    from gi.repository import GLib  # noqa: F401
    HAVE_MODULES = True
except ImportError:
    HAVE_MODULES = False

FILES = 10

# Runs in the sandbox: starts the helper, waits until it owns KIO's names, runs
# the clients and gives the helper and the bridge time to send the endings.
# Each job takes 3 s so the fail and the crash, halfway, come after the 1 s
# before a job is shown.
SCENARIO = """
python3 scripts/kio_jobs.py > "$WORK/kio.log" &
helper=$!
for _ in $(seq 50); do
    grep -q '"active"' "$WORK/kio.log" && break
    sleep 0.1
done
grep -q '"active"' "$WORK/kio.log" || { echo "kio_jobs.py did not take the names" >&2; exit 1; }
for mode in "" --fail --crash; do
    python3 examples/kio_job_client.py $mode --files %d --seconds 3 > /dev/null &
done
wait $(jobs -p | grep -v "^$helper$")
sleep 1.5
kill "$helper"
wait "$helper"
""" % FILES


@unittest.skipUnless(shutil.which("dbus-run-session"), "dbus-run-session not found")
@unittest.skipUnless(HAVE_MODULES, "python3-dbus or PyGObject not installed")
class KioJobsSandboxTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix="kio-sandbox-test.")
        log = os.path.join(cls.work, "activities.jsonl")
        env = dict(os.environ, ISLAND_SANDBOX_LOG=log, WORK=cls.work)
        result = subprocess.run(
            [os.path.join(ROOT, "run.sh"), "--sandbox", "bash", "-c", SCENARIO],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=60,
        )
        if result.returncode != 0:
            raise AssertionError("sandbox run failed (%d):\n%s" % (result.returncode, result.stderr))
        cls.final = {}
        with open(log) as f:
            for line in f:
                for activity in json.loads(line)["activities"]:
                    cls.final[activity["key"]] = activity

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def endings(self, state):
        return [a for a in self.final.values() if a["state"] == state]

    def test_three_jobs_shown(self):
        self.assertEqual(len(self.final), 3, self.final)

    def test_finished_job_is_done(self):
        done = self.endings("done")
        self.assertEqual(len(done), 1, self.final)
        self.assertEqual(done[0]["progress"], 1.0)
        self.assertEqual(done[0]["title"], "Copying %d files" % FILES)

    def test_failed_job_shows_kio_error(self):
        errors = [a["error"] for a in self.endings("failed")]
        self.assertIn("Could not write to /run/media/backup/Pictures: the disk is full.", errors)

    def test_closed_app_fails_job(self):
        errors = [a["error"] for a in self.endings("failed")]
        self.assertIn(kio_jobs_core.APP_CLOSED, errors)


if __name__ == "__main__":
    unittest.main()
