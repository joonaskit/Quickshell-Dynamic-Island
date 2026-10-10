#!/usr/bin/env python3
"""Reference client for the Quickshell Island activities API (docs/ACTIVITIES_API.md).

Shows a fake file copy in the island: progress, a cancel button that the island
reports back, and the finished states. It stays within the API's rules:
  - it checks the API version before using it,
  - it ends every activity with a final state (done, cancelled or failed),
  - it keeps working when the island is not running.

Run it:  python3 examples/activity_client.py [--fail]
Needs python3-dbus and PyGObject (python-gobject), as the shell's helpers do.
"""
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

BUS_NAME = "org.quickshell.IslandActivities"
OBJECT_PATH = "/org/quickshell/IslandActivities"
INTERFACE = "org.quickshell.IslandActivities1"
SUPPORTED_VERSION = 1

ACTIVITY_ID = "example-copy"
FILES = 12
FAIL_AT = 7  # with --fail, the file that can't be copied


class CopyDemo:
    def __init__(self, bus, interface, fail):
        self.bus = bus
        self.api = interface
        self.fail = fail
        self.done = 0
        self.cancelled = False
        self.loop = GLib.MainLoop()

    def start(self):
        self.api.Show(ACTIVITY_ID, {
            "title": f"Copying {FILES} files",
            "text": "Starting…",
            "icon": "folder-copy",
            "progress": 0.0,
            "actions": [("cancel", "Cancel")],
        })
        # Actions come back as a signal. It is sent to everyone on the bus, so
        # match on your own activity id.
        self.bus.add_signal_receiver(self.on_action, "ActionInvoked", INTERFACE, BUS_NAME)
        GLib.timeout_add(400, self.step)
        self.loop.run()

    def on_action(self, activity_id, action):
        if activity_id == ACTIVITY_ID and action == "cancel":
            self.cancelled = True

    def step(self):
        if self.cancelled:
            # Report where it stopped, so the island doesn't imply it finished
            self.api.Update(ACTIVITY_ID, {
                "state": "cancelled",
                "text": f"Cancelled after {self.done} of {FILES} files",
            })
            self.loop.quit()
            return False
        if self.fail and self.done + 1 == FAIL_AT:
            self.api.Update(ACTIVITY_ID, {
                "state": "failed",
                "title": f"Copy failed after {self.done} of {FILES} files",
                "error": "report-2024.pdf: permission denied",
            })
            self.loop.quit()
            return False
        self.done += 1
        if self.done == FILES:
            self.api.Update(ACTIVITY_ID, {"state": "done", "title": f"Copied {FILES} files", "text": ""})
            self.loop.quit()
            return False
        self.api.Update(ACTIVITY_ID, {
            "text": f"file-{self.done + 1:02d}.txt",
            "progress": self.done / FILES,
        })
        return True


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    try:
        obj = bus.get_object(BUS_NAME, OBJECT_PATH)
        props = dbus.Interface(obj, dbus.PROPERTIES_IFACE)
        version = int(props.Get(INTERFACE, "Version"))
    except dbus.DBusException:
        print("The island's activities service is not running; nothing to show.")
        return 1
    if version != SUPPORTED_VERSION:
        print(f"Unsupported activities API version {version}.")
        return 1
    CopyDemo(bus, dbus.Interface(obj, INTERFACE), "--fail" in sys.argv).start()
    return 0


if __name__ == "__main__":
    sys.exit(main())
