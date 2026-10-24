#!/usr/bin/env python3
"""Shows file copies and moves from KDE apps in the island (docs/KIO_JOBS.md).

KIO reports its jobs (Dolphin's copies, moves, deletes, ...) to whoever owns
org.kde.JobViewServer and org.kde.kuiserver, which is Plasma's notification
server when it runs. This helper owns them otherwise, without taking them from
another owner, and forwards each job to the island through the Activities API
(docs/ACTIVITIES_API.md), as any other app would.

Prints one JSON object per line for KioJobsService:
  {"type": "status", "state": "active"}   both names are ours
  {"type": "status", "state": "waiting"}  another program has them; we are queued
"""
import json
import os
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dbus  # noqa: E402
import dbus.mainloop.glib  # noqa: E402
import dbus.service  # noqa: E402
from gi.repository import Gio, GLib  # noqa: E402

import kio_jobs_core as core  # noqa: E402

try:
    from gi.repository import GioUnix  # noqa: E402
    DesktopAppInfo = GioUnix.DesktopAppInfo
except ImportError:
    DesktopAppInfo = Gio.DesktopAppInfo

SERVER_NAMES = ("org.kde.JobViewServer", "org.kde.kuiserver")
SERVER_PATH = "/JobViewServer"
SERVER_IFACE = "org.kde.JobViewServerV2"
KUISERVER_IFACE = "org.kde.kuiserver"
VIEW_IFACE = "org.kde.JobViewV3"

ISLAND_NAME = "org.quickshell.IslandActivities"
ISLAND_PATH = "/org/quickshell/IslandActivities"
ISLAND_IFACE = "org.quickshell.IslandActivities1"
SUPPORTED_VERSION = 1

# The island allows 20 calls a second per app, and all jobs share this helper's
# connection: at most 4 calls every 250 ms keeps under it however many there are
FLUSH_MS = 250
CALLS_PER_FLUSH = 4

# More job views than any desktop runs at once; a client asking for more is broken
MAX_JOBS = 64

ICON_EXTENSIONS = (".png", ".svg", ".jpg", ".webp", ".xpm")


def now_ms():
    return int(time.monotonic() * 1000)


def emit(obj):
    print(json.dumps(obj), flush=True)


def plain(value):
    """A D-Bus value as the plain Python value kio_jobs_core works with"""
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(value, (dbus.Byte, dbus.Int16, dbus.Int32, dbus.Int64, dbus.UInt16, dbus.UInt32, dbus.UInt64)):
        return int(value)
    if isinstance(value, dbus.Double):
        return float(value)
    if isinstance(value, (dbus.String, dbus.ObjectPath)):
        return str(value)
    return value


def plain_map(props):
    return {str(k): plain(v) for k, v in props.items()}


def to_dbus(fields):
    out = {}
    for key, value in fields.items():
        if key == "actions":
            out[key] = dbus.Array([dbus.Struct(a, signature="ss") for a in value], signature="(ss)")
        elif key == "progress":
            out[key] = dbus.Double(value)
        else:
            out[key] = dbus.String(value)
    return dbus.Dictionary(out, signature="sv")


def app_icon(desktop_entry):
    """The icon of the app's desktop entry, in a form the island accepts, or None"""
    try:
        info = DesktopAppInfo.new(desktop_entry + ".desktop")
    except (TypeError, GLib.Error):
        info = None
    icon = info.get_icon() if info is not None else None
    if isinstance(icon, Gio.ThemedIcon):
        names = icon.get_names()
        return names[0] if names else None
    if isinstance(icon, Gio.FileIcon):
        path = icon.get_file().get_path() or ""
        if os.path.isabs(path) and ".." not in path and path.lower().endswith(ICON_EXTENSIONS):
            return path
    return None


class JobView(dbus.service.Object):
    """One job, as KIO sees it. Calls from anyone but the app that asked for it are ignored."""

    def __init__(self, helper, bus, job):
        self.helper = helper
        self.number = job.number
        self.owner = job.owner
        self.path = "%s/JobView_%d" % (SERVER_PATH, job.number)
        super().__init__(bus, self.path)

    @dbus.service.method(VIEW_IFACE, in_signature="a{sv}", sender_keyword="sender")
    def update(self, props, sender=None):
        if sender == self.owner:
            self.helper.on_update(self.number, plain_map(props))

    @dbus.service.method(VIEW_IFACE, in_signature="usa{sv}", sender_keyword="sender")
    def terminate(self, code, message, props, sender=None):
        if sender == self.owner:
            self.helper.on_terminate(self.number, int(code), str(message), plain_map(props))

    @dbus.service.signal(VIEW_IFACE)
    def cancelRequested(self):
        pass

    @dbus.service.signal(VIEW_IFACE)
    def suspendRequested(self):
        pass

    @dbus.service.signal(VIEW_IFACE)
    def resumeRequested(self):
        pass


class Server(dbus.service.Object):
    def __init__(self, helper, bus):
        self.helper = helper
        super().__init__(bus, SERVER_PATH)

    @dbus.service.method(SERVER_IFACE, in_signature="sia{sv}", out_signature="o", sender_keyword="sender")
    def requestView(self, desktop_entry, capabilities, hints, sender=None):
        return self.helper.on_request(str(desktop_entry), int(capabilities), plain_map(hints), sender)

    # KIO asks this first; False means it doesn't also need its own progress dialog
    @dbus.service.method(KUISERVER_IFACE, out_signature="b")
    def requiresJobTracker(self):
        return False


class Helper:
    def __init__(self, bus):
        self.bus = bus
        self.jobs = core.Jobs()
        self.views = {}
        self.watches = {}
        self.owned = set()
        self.island = None
        self.timer = None
        self.state = None
        self.loop = GLib.MainLoop()

    # -- the names KIO looks for ----------------------------------------

    def claim_names(self):
        self.server = Server(self, self.bus)
        for member, handler in (("NameAcquired", self.on_name_acquired), ("NameLost", self.on_name_lost)):
            self.bus.add_signal_receiver(handler, member, "org.freedesktop.DBus", "org.freedesktop.DBus", "/org/freedesktop/DBus")
        for name in SERVER_NAMES:
            # Queued if another program has the name, and given up if one asks for it
            result = self.bus.request_name(name, dbus.bus.NAME_FLAG_ALLOW_REPLACEMENT)
            if result in (dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER, dbus.bus.REQUEST_NAME_REPLY_ALREADY_OWNER):
                self.owned.add(name)
        self.report()

    def on_name_acquired(self, name):
        if name in SERVER_NAMES:
            self.owned.add(name)
            self.report()

    def on_name_lost(self, name):
        if name in SERVER_NAMES:
            self.owned.discard(name)
            self.report()

    def report(self):
        state = "active" if self.owned == set(SERVER_NAMES) else "waiting"
        if state != self.state:
            self.state = state
            emit({"type": "status", "state": state})

    # -- KIO ------------------------------------------------------------

    def on_request(self, desktop_entry, capabilities, hints, sender):
        if len(self.jobs.jobs) >= MAX_JOBS:
            raise dbus.exceptions.DBusException("Too many jobs", name="org.kde.JobViewServer.Error.LimitExceeded")
        job = self.jobs.add(sender, app_icon(desktop_entry), capabilities, hints, now_ms())
        view = JobView(self, self.bus, job)
        self.views[job.number] = view
        if sender not in self.watches:
            self.watches[sender] = self.bus.watch_name_owner(sender, lambda owner, s=sender: self.on_owner(s, owner))
        self.wake()
        return dbus.ObjectPath(view.path)

    def on_update(self, number, props):
        self.jobs.update(number, props)
        self.wake()

    def on_terminate(self, number, code, message, props):
        self.jobs.update(number, props)
        self.jobs.terminate(number, code, message)
        self.drop_view(number)
        self.wake()

    def on_owner(self, sender, owner):
        if owner:
            return
        self.jobs.owner_gone(sender)
        for number in [n for n, v in self.views.items() if v.owner == sender]:
            self.drop_view(number)
        watch = self.watches.pop(sender, None)
        if watch is not None:
            watch.cancel()
        self.wake()

    def drop_view(self, number):
        view = self.views.pop(number, None)
        if view is not None:
            view.remove_from_connection()

    # -- the island -----------------------------------------------------

    def watch_island(self):
        self.bus.watch_name_owner(ISLAND_NAME, self.on_island_owner)
        self.bus.add_signal_receiver(self.on_action, "ActionInvoked", ISLAND_IFACE, ISLAND_NAME)
        self.bus.add_signal_receiver(self.on_dismissed, "Dismissed", ISLAND_IFACE, ISLAND_NAME)

    def on_island_owner(self, owner):
        self.island = self.connect_island() if owner else None
        # A new island knows nothing of what the old one showed
        self.jobs.island_restarted()
        self.wake()

    def connect_island(self):
        try:
            obj = self.bus.get_object(ISLAND_NAME, ISLAND_PATH, introspect=False)
            version = dbus.Interface(obj, dbus.PROPERTIES_IFACE).Get(ISLAND_IFACE, "Version", timeout=5)
            if int(version) != SUPPORTED_VERSION:
                print("kio_jobs.py: unsupported Activities API version %s" % version, file=sys.stderr)
                return None
            return dbus.Interface(obj, ISLAND_IFACE)
        except dbus.exceptions.DBusException as err:
            print("kio_jobs.py: cannot reach the island: %s" % err, file=sys.stderr)
            return None

    def on_action(self, activity_id, action):
        if action != "cancel":
            return
        job = self.jobs.cancel_requested(str(activity_id))
        view = self.views.get(job.number) if job is not None else None
        if view is not None:
            view.cancelRequested()

    def on_dismissed(self, activity_id):
        self.jobs.dismissed(str(activity_id))

    def call(self, method, activity_id, fields):
        def failed(err):
            name = err.get_dbus_name() or ""
            code = name.rsplit(".", 1)[-1]
            if code not in ("RateLimited", "NotFound"):
                print("kio_jobs.py: %s %s: %s" % (method, activity_id, err), file=sys.stderr)
            self.jobs.call_failed(activity_id, method, code)
            self.wake()
        getattr(self.island, method)(activity_id, to_dbus(fields), reply_handler=lambda: None, error_handler=failed)

    # -- running --------------------------------------------------------

    def wake(self):
        if self.timer is None and self.jobs.jobs:
            self.timer = GLib.timeout_add(FLUSH_MS, self.tick)

    def tick(self):
        if self.island is not None:
            for method, activity_id, fields in self.jobs.take_calls(now_ms(), CALLS_PER_FLUSH):
                self.call(method, activity_id, fields)
        if not self.jobs.jobs:
            self.timer = None
            return False
        return True

    def stop(self):
        # Take our running jobs out of the island, or it would report them as failed
        # once we are gone, while the copies themselves carry on
        if self.island is not None:
            for job in self.jobs.visible_running():
                try:
                    self.island.Dismiss(job.id, timeout=1)
                except dbus.exceptions.DBusException:
                    pass
        for name in SERVER_NAMES:
            try:
                self.bus.release_name(name)
            except dbus.exceptions.DBusException:
                pass
        self.loop.quit()
        return False

    def run(self):
        self.claim_names()
        self.watch_island()
        try:
            from gi.repository import GLibUnix
            unix_signal_add = GLibUnix.signal_add
        except ImportError:
            unix_signal_add = GLib.unix_signal_add
        for number in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            unix_signal_add(GLib.PRIORITY_DEFAULT, number, self.stop)
        self.loop.run()


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    Helper(dbus.SessionBus()).run()


if __name__ == "__main__":
    main()
