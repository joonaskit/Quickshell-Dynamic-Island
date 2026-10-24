#!/usr/bin/env python3
"""A fake KIO job, for trying scripts/kio_jobs.py without a large copy (docs/KIO_JOBS.md).

Talks to org.kde.JobViewServer the way KIO does for Dolphin: asks for a job
view, sends progress with update(), and ends it with terminate(). The island's
Cancel button reaches it as cancelRequested, and it then ends as KIO would.

Run it:  python3 examples/kio_job_client.py [--fail | --crash] [--files N] [--seconds S]
  --fail     ends with an error halfway, as a copy to a full disk would
  --crash    exits halfway without ending the job, as a crashed app would
Needs python3-dbus and PyGObject (python-gobject), as the shell's helpers do.
"""
import argparse
import os
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

SERVER_NAME = "org.kde.JobViewServer"
SERVER_PATH = "/JobViewServer"
SERVER_IFACE = "org.kde.JobViewServerV2"
VIEW_IFACE = "org.kde.JobViewV3"

KILLABLE = 1
KILLED = 1               # KJob::KilledJobError, what KIO sends for a cancelled job
ERR_DISK_FULL = 135      # KIO::ERR_DISK_FULL
FILE_SIZE = 2_500_000
TICK_MS = 200


def variant_map(props):
    return dbus.Dictionary(props, signature="sv")


class FakeJob:
    def __init__(self, bus, args):
        self.bus = bus
        self.args = args
        self.files = args.files
        self.done = 0
        self.ticks = 0
        self.total_ticks = max(1, int(args.seconds * 1000 / TICK_MS))
        self.loop = GLib.MainLoop()
        self.view = None

    def props(self):
        name = "photo-%04d.jpg" % min(self.done + 1, self.files)
        return {
            "title": dbus.String("Copying"),
            "descriptionLabel1": dbus.String("Source"),
            "descriptionValue1": dbus.String(os.path.expanduser("~/Pictures/") + name),
            "descriptionLabel2": dbus.String("Destination"),
            "descriptionValue2": dbus.String("/run/media/backup/Pictures/" + name),
            "percent": dbus.UInt32(self.done * 100 // self.files),
            "processedFiles": dbus.UInt64(self.done),
            "totalFiles": dbus.UInt64(self.files),
            "processedBytes": dbus.UInt64(self.done * FILE_SIZE),
            "totalBytes": dbus.UInt64(self.files * FILE_SIZE),
            "elapsedTime": dbus.Int64(self.ticks * TICK_MS),
        }

    def start(self):
        server = dbus.Interface(self.bus.get_object(SERVER_NAME, SERVER_PATH), SERVER_IFACE)
        path = server.requestView("org.kde.dolphin", KILLABLE, variant_map(self.props()))
        self.view = dbus.Interface(self.bus.get_object(SERVER_NAME, path), VIEW_IFACE)
        self.bus.add_signal_receiver(self.on_cancel, "cancelRequested", VIEW_IFACE, SERVER_NAME, path)
        print("Job view %s. Press Cancel in the island to stop it." % path)
        GLib.timeout_add(TICK_MS, self.tick)
        self.loop.run()

    def tick(self):
        self.ticks += 1
        self.done = min(self.files, self.ticks * self.files // self.total_ticks)
        halfway = self.done >= self.files // 2
        if self.args.crash and halfway:
            print("Exiting without ending the job")
            os._exit(1)
        if self.args.fail and halfway:
            return self.end(ERR_DISK_FULL, "Could not write to /run/media/backup/Pictures: the disk is full.")
        props = self.props()
        props["speed"] = dbus.UInt64(FILE_SIZE * self.files * 1000 // (self.total_ticks * TICK_MS))
        self.view.update(variant_map(props))
        if self.done >= self.files:
            return self.end(0, "")
        return True

    def on_cancel(self):
        print("Cancel requested after %d of %d files" % (self.done, self.files))
        self.end(KILLED, "")

    def end(self, code, message):
        self.view.update(variant_map(self.props()))
        self.view.terminate(dbus.UInt32(code), message, variant_map({}))
        print("Ended with code %d" % code)
        self.loop.quit()
        return False


def main():
    parser = argparse.ArgumentParser(description="Show a fake KIO copy in the island.")
    ending = parser.add_mutually_exclusive_group()
    ending.add_argument("--fail", action="store_true", help="end with an error halfway")
    ending.add_argument("--crash", action="store_true", help="exit halfway without ending the job")
    parser.add_argument("--files", type=int, default=240, help="how many files the copy has (default 240)")
    parser.add_argument("--seconds", type=float, default=12, help="how long it takes (default 12)")
    args = parser.parse_args()

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    if not bus.name_has_owner(SERVER_NAME):
        print("Nothing owns %s: is the island running with Show File Copy Progress on?" % SERVER_NAME)
        return 1
    FakeJob(bus, args).start()
    return 0


if __name__ == "__main__":
    sys.exit(main())
