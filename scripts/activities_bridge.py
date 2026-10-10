#!/usr/bin/env python3
"""D-Bus side of the activities API (docs/ACTIVITIES_API.md).

Owns org.quickshell.IslandActivities on the session bus. Other apps call Show,
Update and Dismiss; the shell reads the result from stdout and answers on stdin.

To the shell (stdout), one JSON object per line:
  {"type": "state", "activities": [...]}   the full list, in pill order, after every change

From the shell (stdin), one JSON object per line:
  {"cmd": "action", "key": "<key>", "action": "<action id>"}   the user pressed an action
  {"cmd": "dismiss", "key": "<key>"}                           the user dismissed an activity
"""
import json
import os
import signal
import sys
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import activities_core as core  # noqa: E402

BUS_NAME = "org.quickshell.IslandActivities"
OBJECT_PATH = "/org/quickshell/IslandActivities"
INTERFACE = "org.quickshell.IslandActivities1"
ERROR_PREFIX = "org.quickshell.IslandActivities.Error."

# State changes are sent to the shell at most this often, so a client updating
# progress in a tight loop doesn't make the pill re-render for every call
PUBLISH_INTERVAL_MS = 80


def to_python(value):
    """Convert dbus-python types (dbus.String, dbus.Double, dbus.Array, ...) to plain Python."""
    if isinstance(value, dbus.Boolean):
        return bool(value)
    if isinstance(value, (dbus.Double, float)):
        return float(value)
    if isinstance(value, (dbus.Int16, dbus.Int32, dbus.Int64, dbus.UInt16, dbus.UInt32, dbus.UInt64, dbus.Byte, int)):
        return int(value)
    if isinstance(value, str):
        return str(value)
    if isinstance(value, (list, tuple)):
        return [to_python(v) for v in value]
    if isinstance(value, dict):
        return {str(k): to_python(v) for k, v in value.items()}
    return value


def raise_dbus(err):
    raise dbus.exceptions.DBusException(err.message, name=ERROR_PREFIX + err.code)


class ActivityService(dbus.service.Object):
    def __init__(self, bus, store):
        super().__init__(bus, OBJECT_PATH)
        self.bus = bus
        self.store = store
        self.watches = {}  # sender -> NameOwnerWatch
        self.publish_source = None
        self.expiry_source = None

    # -- D-Bus interface ---------------------------------------------------

    @dbus.service.method(INTERFACE, in_signature="sa{sv}", out_signature="", sender_keyword="sender")
    def Show(self, activity_id, fields, sender=None):
        self._call(lambda: self.store.show(sender, str(activity_id), to_python(fields)), sender)

    @dbus.service.method(INTERFACE, in_signature="sa{sv}", out_signature="", sender_keyword="sender")
    def Update(self, activity_id, fields, sender=None):
        self._call(lambda: self.store.update(sender, str(activity_id), to_python(fields)), sender)

    @dbus.service.method(INTERFACE, in_signature="s", out_signature="", sender_keyword="sender")
    def Dismiss(self, activity_id, sender=None):
        self._call(lambda: self.store.dismiss(sender, str(activity_id)), sender)

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != INTERFACE:
            return {}
        return {"Version": dbus.UInt32(core.API_VERSION)}

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        if interface == INTERFACE and name == "Version":
            return dbus.UInt32(core.API_VERSION)
        raise dbus.exceptions.DBusException(f"Unknown property {name}", name="org.freedesktop.DBus.Error.UnknownProperty")

    @dbus.service.signal(INTERFACE, signature="ss")
    def ActionInvoked(self, activity_id, action):
        pass

    @dbus.service.signal(INTERFACE, signature="s")
    def Dismissed(self, activity_id):
        pass

    # -- calls from the shell ----------------------------------------------

    def handle_command(self, line):
        try:
            cmd = json.loads(line)
        except ValueError:
            return
        if not isinstance(cmd, dict):
            return
        item = self.store.get_key(cmd.get("key", ""))
        if item is None:
            return
        if cmd.get("cmd") == "action":
            known = {a["id"] for a in item["actions"]}
            if cmd.get("action") in known and not item.get("orphaned"):
                self.ActionInvoked(item["id"], cmd["action"])
        elif cmd.get("cmd") == "dismiss":
            self.store.dismiss_key(cmd["key"])
            if not item.get("orphaned"):
                self.Dismissed(item["id"])
            self.after_change()

    # -- plumbing ----------------------------------------------------------

    def _call(self, fn, sender):
        try:
            fn()
        except core.ActivityError as err:
            raise_dbus(err)
        if sender not in self.watches:
            self.watches[sender] = self.bus.watch_name_owner(sender, lambda owner, s=sender: self.on_owner(s, owner))
        self.after_change()

    def on_owner(self, sender, owner):
        # An empty owner means the sender left the bus (exited or crashed)
        if owner:
            return
        watch = self.watches.pop(sender, None)
        if watch is not None:
            watch.cancel()
        if self.store.sender_gone(sender):
            self.after_change()

    def after_change(self):
        # Drop watches for senders that have nothing left
        live = self.store.senders()
        for sender in [s for s in self.watches if s not in live]:
            self.watches.pop(sender).cancel()
        if self.publish_source is None:
            self.publish_source = GLib.timeout_add(PUBLISH_INTERVAL_MS, self.publish)
        self.schedule_expiry()

    def schedule_expiry(self):
        if self.expiry_source is not None:
            GLib.source_remove(self.expiry_source)
            self.expiry_source = None
        wait = self.store.next_expiry()
        if wait is not None:
            self.expiry_source = GLib.timeout_add(int(wait * 1000) + 20, self.on_expiry)

    def on_expiry(self):
        self.expiry_source = None
        if self.store.expire():
            self.after_change()
        else:
            self.schedule_expiry()
        return False

    def publish(self):
        self.publish_source = None
        emit({"type": "state", "activities": self.store.snapshot()})
        return False


def emit(payload):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    try:
        bus = dbus.SessionBus()
    except Exception as e:
        sys.stderr.write(f"Failed to connect to session bus: {e}\n")
        sys.exit(1)

    try:
        # Keep a reference: the name is released when BusName is garbage collected
        bus_name = dbus.service.BusName(BUS_NAME, bus, do_not_queue=True)  # noqa: F841
    except dbus.exceptions.NameExistsException:
        sys.stderr.write(f"{BUS_NAME} is already owned by another process\n")
        sys.exit(1)

    service = ActivityService(bus, core.ActivityStore(time.monotonic))
    emit({"type": "state", "activities": []})

    loop = GLib.MainLoop()

    pending = bytearray()

    def on_stdin(fd, condition):
        # Read the fd directly: a buffered readline() could hold complete lines
        # that the watch never reports again
        data = os.read(fd, 65536) if condition & GLib.IO_IN else b""
        if not data:
            # The shell closed our stdin: it is gone, so are we
            loop.quit()
            return False
        pending.extend(data)
        while b"\n" in pending:
            line, _, rest = bytes(pending).partition(b"\n")
            pending[:] = rest
            service.handle_command(line.decode("utf-8", errors="replace"))
        return True

    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)

    signal.signal(signal.SIGINT, lambda *a: loop.quit())
    signal.signal(signal.SIGTERM, lambda *a: loop.quit())
    loop.run()


if __name__ == "__main__":
    main()
