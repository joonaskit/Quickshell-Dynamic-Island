#!/usr/bin/env python3
"""A window of buttons for trying the activities API (docs/ACTIVITIES_API.md) by hand.

Each button starts a scenario in the island: progress, a failure, a cancel
button that reports back, several at once, and so on. The log shows what the
island sends back (actions, dismissals) and any errors the API returns.

Run it with the shell running:  python3 examples/activity_tester.py
Needs python-dbus and PyGObject like the shell's helpers, plus tkinter
(Debian/Ubuntu: python3-tk, Arch: tk, Fedora: python3-tkinter).

Closing the window while something is running leaves it unfinished, which the
island shows as a failure ("The app closed before the operation finished").
"""
import itertools
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

BUS_NAME = "org.quickshell.IslandActivities"
OBJECT_PATH = "/org/quickshell/IslandActivities"
INTERFACE = "org.quickshell.IslandActivities1"
SUPPORTED_VERSION = 1

STEP_MS = 400


class Tester:
    """The scenarios. `schedule(ms, fn)` runs fn after ms, and again while fn returns True."""

    def __init__(self, api, schedule, log):
        self.api = api
        self.schedule = schedule
        self.log = log
        self.counter = itertools.count(1)
        self.cancel_requested = set()
        self.live = set()

    # -- D-Bus helpers -----------------------------------------------------

    def call(self, name, *args):
        """Call the API, logging an error instead of raising. Returns whether it worked."""
        try:
            getattr(self.api, name)(*args)
            return True
        except dbus.DBusException as e:
            self.log(f"{name} failed: {e.get_dbus_name().rsplit('.', 1)[-1]}: {e.get_dbus_message()}")
            return False

    def new_id(self, prefix):
        activity_id = f"{prefix}-{next(self.counter)}"
        self.live.add(activity_id)
        return activity_id

    def finish(self, activity_id, fields):
        self.call("Update", activity_id, fields)
        self.live.discard(activity_id)
        self.cancel_requested.discard(activity_id)

    # -- signals from the island -------------------------------------------

    def on_action(self, activity_id, action):
        if activity_id not in self.live:
            return  # someone else's, or finished
        self.log(f"action '{action}' on {activity_id}")
        if action == "cancel":
            self.cancel_requested.add(activity_id)
        elif action == "retry":
            self.log("(retry: starting a new copy)")
            self.copy()

    def on_dismissed(self, activity_id):
        if activity_id in self.live:
            self.log(f"dismissed {activity_id}")

    # -- scenarios ---------------------------------------------------------

    def copy(self, files=12, title=None, priority="normal"):
        """Progress with a cancel button. Reports where it stopped if cancelled."""
        activity_id = self.new_id("copy")
        self.call("Show", activity_id, {
            "title": title or f"Copying {files} files",
            "text": "Starting…",
            "icon": "folder-copy",
            "progress": 0.0,
            "priority": priority,
            "actions": [("cancel", "Cancel")],
        })
        done = [0]

        def step():
            if activity_id in self.cancel_requested:
                self.finish(activity_id, {"state": "cancelled", "text": f"Cancelled after {done[0]} of {files} files"})
                return False
            done[0] += 1
            if done[0] >= files:
                self.finish(activity_id, {"state": "done", "text": "", "title": f"Copied {files} files"})
                return False
            self.call("Update", activity_id, {"text": f"file-{done[0] + 1:02d}.txt", "progress": done[0] / files})
            return True

        self.schedule(STEP_MS, step)

    def indeterminate(self):
        """The total is not known: a negative progress."""
        activity_id = self.new_id("scan")
        self.call("Show", activity_id, {
            "title": "Counting files",
            "text": "This may take a while",
            "icon": "system-search",
            "progress": -1.0,
            "actions": [("cancel", "Cancel")],
        })
        ticks = [0]

        def step():
            if activity_id in self.cancel_requested:
                self.finish(activity_id, {"state": "cancelled", "text": "Cancelled"})
                return False
            ticks[0] += 1
            if ticks[0] >= 8:
                self.finish(activity_id, {"state": "done", "title": "Counted 1,204 files", "text": ""})
                return False
            return True

        self.schedule(STEP_MS * 2, step)

    def text_only(self):
        """No progress at all: just a line of text for a few seconds."""
        activity_id = self.new_id("static")
        self.call("Show", activity_id, {"title": "Syncing", "text": "Waiting for the server", "icon": "emblem-synchronizing"})
        self.schedule(4000, lambda: self.finish(activity_id, {"state": "done", "title": "Synced", "text": ""}) and False)

    def fail(self):
        """Fails halfway and stays until dismissed. Has a Retry action."""
        activity_id = self.new_id("fail")
        self.call("Show", activity_id, {"title": "Moving 8 files", "text": "file-01.txt", "icon": "folder-copy", "progress": 0.0})
        steps = [0]

        def step():
            steps[0] += 1
            if steps[0] >= 4:
                # Not finish(): it stays in `live`, so Retry and Dismissed are still logged
                self.call("Update", activity_id, {
                    "state": "failed",
                    "title": "Move failed after 4 of 8 files",
                    "error": "report-2024.pdf: permission denied",
                    "actions": [("retry", "Retry")],
                })
                return False
            self.call("Update", activity_id, {"progress": steps[0] / 8, "text": f"file-{steps[0] + 1:02d}.txt"})
            return True

        self.schedule(STEP_MS, step)

    def quick_done(self):
        """Finishes at once: shows 'Done' for a moment."""
        activity_id = self.new_id("quick")
        self.call("Show", activity_id, {"title": "Copied 1 file", "state": "done", "icon": "folder-copy"})
        self.live.discard(activity_id)

    def high_priority(self):
        self.copy(files=20, title="Important backup (high priority)", priority="high")

    def low_priority(self):
        self.copy(files=20, title="Thumbnails (low priority)", priority="low")

    def several(self):
        for n in range(3):
            self.copy(files=10 + n * 4, title=f"Copy job {n + 1} of 3")

    def spam(self):
        """Far more calls than the rate limit allows; expect RateLimited errors in the log."""
        activity_id = self.new_id("spam")
        self.call("Show", activity_id, {"title": "Rate limit test", "progress": 0.0})
        rejected = 0
        for n in range(100):
            if not self.call_quiet("Update", activity_id, {"progress": n / 100}):
                rejected += 1
        self.log(f"sent 100 updates, {rejected} rejected")
        self.schedule(2000, lambda: self.finish(activity_id, {"state": "done", "title": "Rate limit test done"}) and False)

    def call_quiet(self, name, *args):
        try:
            getattr(self.api, name)(*args)
            return True
        except dbus.DBusException:
            return False

    def bad_input(self):
        """Calls the API rejects; each should log an error and leave the island alone."""
        self.call("Show", "bad-1", {"title": "x", "progress": "half"})
        self.call("Show", "bad-2", {"colour": "red"})
        self.call("Show", "bad-3", {"icon": "../../etc/passwd"})
        self.call("Update", "does-not-exist", {"progress": 0.5})

    def dismiss_all(self):
        for activity_id in sorted(self.live):
            self.call("Dismiss", activity_id)
        self.live.clear()
        self.log("dismissed everything this window started (failed ones left by earlier runs stay until you dismiss them)")


BUTTONS = [
    ("Copy files (with Cancel)", "copy"),
    ("Indeterminate progress", "indeterminate"),
    ("Text only, no progress", "text_only"),
    ("Fails halfway (Retry)", "fail"),
    ("Done at once", "quick_done"),
    ("High priority copy", "high_priority"),
    ("Low priority copy", "low_priority"),
    ("Three at once", "several"),
    ("Rate limit spam", "spam"),
    ("Invalid calls", "bad_input"),
    ("Dismiss all", "dismiss_all"),
]


def connect():
    """Returns the API interface, or None (with a message) if it can't be used."""
    bus = dbus.SessionBus()
    try:
        obj = bus.get_object(BUS_NAME, OBJECT_PATH)
        version = int(dbus.Interface(obj, dbus.PROPERTIES_IFACE).Get(INTERFACE, "Version"))
    except dbus.DBusException:
        print("The island's activities service is not running. Start the shell first (./run.sh).")
        return None, None
    if version != SUPPORTED_VERSION:
        print(f"Unsupported activities API version {version}.")
        return None, None
    return bus, dbus.Interface(obj, INTERFACE)


def main():
    import tkinter as tk
    from tkinter import scrolledtext

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus, api = connect()
    if api is None:
        return 1

    root = tk.Tk()
    root.title("Island activities tester")
    root.geometry("360x560")

    logbox = scrolledtext.ScrolledText(root, height=10, state="disabled", font=("monospace", 9))

    def log(message):
        logbox.configure(state="normal")
        logbox.insert("end", message + "\n")
        logbox.see("end")
        logbox.configure(state="disabled")

    def schedule(ms, fn):
        def run():
            if fn():
                root.after(ms, run)
        root.after(ms, run)

    tester = Tester(api, schedule, log)
    bus.add_signal_receiver(tester.on_action, "ActionInvoked", INTERFACE, BUS_NAME)
    bus.add_signal_receiver(tester.on_dismissed, "Dismissed", INTERFACE, BUS_NAME)

    for label, method in BUTTONS:
        tk.Button(root, text=label, command=getattr(tester, method)).pack(fill="x", padx=10, pady=2)
    tk.Label(root, text="Log").pack(anchor="w", padx=10, pady=(8, 0))
    logbox.pack(fill="both", expand=True, padx=10, pady=(0, 10))

    # Let D-Bus signals through while Tk runs the main loop
    context = GLib.MainContext.default()

    def pump():
        while context.pending():
            context.iteration(False)
        root.after(30, pump)

    pump()
    log("Connected, API version 1")
    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
