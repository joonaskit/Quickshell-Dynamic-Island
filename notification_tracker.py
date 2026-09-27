#!/usr/bin/env python3
import sys
import os
import json
import time
import signal
import random
import dbus
import dbus.lowlevel
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

def handle_sigterm(signum, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

def main():
    try:
        DBusGMainLoop(set_as_default=True)
        bus = dbus.SessionBus()
        dbus_obj = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
        dbus_iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus.Monitoring")

        match_rule = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
        dbus_iface.BecomeMonitor([match_rule], dbus.UInt32(0))

        def msg_handler(connection, message):
            try:
                if message.get_type() == dbus.lowlevel.MESSAGE_TYPE_METHOD_CALL:
                    if message.get_member() == "Notify":
                        args = message.get_args_list()
                        app_name = str(args[0]) if len(args) > 0 else "System"
                        app_icon = str(args[2]) if len(args) > 2 else ""
                        summary = str(args[3]) if len(args) > 3 else ""
                        body = str(args[4]) if len(args) > 4 else ""

                        # Skip empty or test notification pings if summary & body are both blank
                        if not summary and not body:
                            return dbus.lowlevel.HANDLER_RESULT_HANDLED

                        now_ms = int(time.time() * 1000)
                        uid = f"notif_{now_ms}_{random.randint(100, 999)}"

                        data = {
                            "id": uid,
                            "appName": app_name,
                            "appIcon": app_icon,
                            "summary": summary,
                            "body": body,
                            "time": time.strftime("%H:%M"),
                            "timestamp": now_ms
                        }
                        sys.stdout.write(json.dumps(data) + "\n")
                        sys.stdout.flush()
            except Exception as e:
                sys.stderr.write(f"Notification parse error: {e}\n")
            return dbus.lowlevel.HANDLER_RESULT_HANDLED

        bus.add_message_filter(msg_handler)
        loop = GLib.MainLoop()
        loop.run()
    except Exception as e:
        sys.stderr.write(f"Notification tracker fatal error: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
