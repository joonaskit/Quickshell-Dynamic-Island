"""Prints a service's state again whenever it changes, for the `watch` commands of
gamemode.py and kdeconnect.py.

Any signal the service sends, and the service appearing on or leaving the session
bus, schedules one read. Reads wait for a burst of signals to end, and a state
equal to the last one printed is not printed again.
"""
import json

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

# Signals come in bursts (a device connecting sends several), so wait for a gap
SETTLE_MS = 300


def watch(service, read):
    """read() returns the state as a JSON-serializable value. Never returns."""
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    last = [None]
    pending = [None]

    def emit():
        pending[0] = None
        line = json.dumps(read())
        if line != last[0]:
            last[0] = line
            print(line, flush=True)
        return False

    def schedule(*_args, **_kwargs):
        if pending[0] is not None:
            GLib.source_remove(pending[0])
        pending[0] = GLib.timeout_add(SETTLE_MS, emit)

    # bus_name follows whichever process owns the name, so a restarted daemon is still heard
    bus.add_signal_receiver(schedule, bus_name=service)
    bus.watch_name_owner(service, schedule)
    emit()
    GLib.MainLoop().run()
