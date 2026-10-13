#!/usr/bin/env python3
"""Run a command and show it as an activity in the island (docs/ACTIVITIES_API.md).

  island_run.py [options] [--] COMMAND [ARGS...]

The command runs as normal: its output still goes to your terminal, its exit
code is the wrapper's exit code, and it works the same when the island is not
running (the command is then simply run). While it runs, the island shows its
last line of output and, when the output has a percentage or a "[3/12]" count,
a progress bar. It ends as done, failed (with the exit code and the last line)
or cancelled (Ctrl+C, SIGTERM, or the Cancel button in the island).

Examples:
  island_run.py rsync -a --info=progress2 ~/Photos /mnt/backup
  island_run.py --title "System update" sudo dnf upgrade
  island_run.py --progress none make -j8

Needs python3-dbus and PyGObject, as the shell's helpers do. Without them, or
without the island, the command is run directly.
"""
import argparse
import codecs
import errno
import fcntl
import os
import pty
import signal
import struct
import subprocess
import sys
import termios

# realpath, because island-run is a link to this file and the core module sits next to the real one
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))

import island_run_core as core  # noqa: E402

BUS_NAME = "org.quickshell.IslandActivities"
OBJECT_PATH = "/org/quickshell/IslandActivities"
INTERFACE = "org.quickshell.IslandActivities1"
SUPPORTED_VERSION = 1

# Updates go out at most this often. The island allows 20 calls a second, and a
# progress bar redrawn in a tight loop doesn't need more than a few
UPDATE_INTERVAL_MS = 250


def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="island_run.py",
        description="Run a command and show its progress in the island.",
        usage="%(prog)s [options] [--] COMMAND [ARGS...]",
    )
    parser.add_argument("--title", help="headline in the island (default: the command line)")
    parser.add_argument("--icon", help="icon theme name or absolute path to an image")
    parser.add_argument("--priority", choices=["low", "normal", "high"], default="normal")
    parser.add_argument("--progress", choices=sorted(core.PARSERS), default="auto",
                        help="how to read progress from the output (default: auto, a percentage or [done/total])")
    parser.add_argument("--no-text", action="store_true", help="do not show the command's last line of output")
    parser.add_argument("--no-cancel", action="store_true", help="do not offer a Cancel button")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("no command given")
    return args


def connect():
    """The activities interface, or None when the island, D-Bus or Python's bindings are not there."""
    try:
        import dbus
        import dbus.mainloop.glib
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SessionBus()
        obj = bus.get_object(BUS_NAME, OBJECT_PATH)
        props = dbus.Interface(obj, dbus.PROPERTIES_IFACE)
        if int(props.Get(INTERFACE, "Version")) != SUPPORTED_VERSION:
            return None
        return bus, dbus.Interface(obj, INTERFACE)
    except Exception:
        return None


def run_plain(command):
    try:
        os.execvp(command[0], command)
    except OSError as err:
        return report_spawn_error(command, err)


def report_spawn_error(command, err):
    print("island_run.py: %s: %s" % (command[0], err.strerror), file=sys.stderr)
    return 126 if err.errno == errno.EACCES else 127


class Reader:
    """One of the command's output streams: passed through unchanged, and read for progress."""

    def __init__(self, fd, out):
        self.fd = fd
        self.out = out
        self.open = True
        self.decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        self.unfinished = ""


class Runner:
    def __init__(self, bus, api, args):
        from gi.repository import GLib
        self.GLib = GLib
        try:
            from gi.repository import GLibUnix
            self.unix_signal_add = GLibUnix.signal_add
        except ImportError:
            self.unix_signal_add = GLib.unix_signal_add
        self.bus = bus
        self.api = api
        self.args = args
        self.id = "run-%d" % os.getpid()
        self.title = args.title or core.default_title(args.command)
        self.parse = core.PARSERS[args.progress]
        self.pending = {}
        self.last_line = ""
        self.proc = None
        self.returncode = None
        self.readers = []
        self.master = None
        self.loop = GLib.MainLoop()
        self.tty = sys.stdout.isatty()

    # -- the island -----------------------------------------------------

    def call(self, name, *params):
        if self.api is None:
            return
        try:
            getattr(self.api, name)(*params)
        except Exception as err:
            # Over the rate limit is a passing problem. Anything else (the island
            # closed, or the user dismissed the activity) means stop reporting
            dbus_name = getattr(err, "get_dbus_name", lambda: "")()
            if not dbus_name.endswith("RateLimited"):
                self.api = None

    def show(self):
        fields = {"title": self.title, "progress": -1.0, "priority": self.args.priority}
        if self.args.icon:
            fields["icon"] = self.args.icon
        if not self.args.no_cancel:
            fields["actions"] = [("cancel", "Cancel")]
        self.call("Show", self.id, fields)
        if not self.args.no_cancel:
            self.bus.add_signal_receiver(self.on_action, "ActionInvoked", INTERFACE, BUS_NAME)

    def on_action(self, activity_id, action):
        if activity_id == self.id and action == "cancel":
            self.signal_child(signal.SIGTERM)

    def flush(self):
        if self.pending:
            fields, self.pending = self.pending, {}
            self.call("Update", self.id, fields)
        return True

    # -- the command ----------------------------------------------------

    def spawn(self):
        if self.tty:
            # A terminal makes programs draw their progress bars, as they would without the wrapper
            self.master, slave = pty.openpty()
            self.resize()
            out = err = slave
        else:
            slave = None
            out = err = subprocess.PIPE
        try:
            self.proc = subprocess.Popen(self.args.command, stdout=out, stderr=err)
        except OSError as err_:
            if slave is not None:
                os.close(slave)
                os.close(self.master)
            raise err_
        if self.tty:
            os.close(slave)
            self.readers = [Reader(self.master, sys.stdout.buffer)]
        else:
            self.readers = [Reader(self.proc.stdout.fileno(), sys.stdout.buffer),
                            Reader(self.proc.stderr.fileno(), sys.stderr.buffer)]

    def resize(self):
        try:
            size = fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0))
            fcntl.ioctl(self.master, termios.TIOCSWINSZ, size)
        except OSError:
            pass

    def signal_child(self, number):
        if self.proc is not None and self.returncode is None:
            try:
                self.proc.send_signal(number)
            except OSError:
                pass

    def on_input(self, reader):
        def callback(fd, condition):
            self.read(reader)
            return reader.open
        return callback

    def read(self, reader, drain=False):
        """Read what is available. With drain, read until the stream is empty."""
        while reader.open:
            try:
                data = os.read(reader.fd, 65536)
            except BlockingIOError:
                return
            except OSError:
                data = b""  # a closed terminal reports EIO
            if not data:
                reader.open = False
                return
            reader.out.write(data)
            reader.out.flush()
            self.look(reader, reader.decoder.decode(data))
            if not drain:
                return

    def look(self, reader, text):
        lines, reader.unfinished = core.split_output(reader.unfinished, text)
        for line in lines:
            line = line.strip()
            self.last_line = line
            if not self.args.no_text:
                self.pending["text"] = line
            value = self.parse(line)
            if value is not None:
                self.pending["progress"] = value

    def on_exit(self, pid, status):
        self.returncode = os.waitstatus_to_exitcode(status)
        self.proc.returncode = self.returncode
        for reader in self.readers:
            os.set_blocking(reader.fd, False)
            self.read(reader, drain=True)
        self.pending.update(core.describe_exit(self.title, self.returncode, self.last_line))
        if self.pending.get("state") == "failed":
            self.pending["title"] = "Failed: " + self.title
        self.flush()
        self.loop.quit()

    # -- running --------------------------------------------------------

    def run(self):
        GLib = self.GLib
        self.spawn()
        self.show()
        for reader in self.readers:
            GLib.io_add_watch(reader.fd, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, self.on_input(reader))
        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, self.proc.pid, self.on_exit)
        GLib.timeout_add(UPDATE_INTERVAL_MS, self.flush)
        for number in (signal.SIGTERM, signal.SIGHUP):
            self.unix_signal_add(GLib.PRIORITY_DEFAULT, number, self.forward, number)
        # On a terminal, Ctrl+C already reaches the command; sending it again would hit it twice
        self.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.forward_interrupt)
        if self.tty:
            self.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGWINCH, self.on_resize)
        self.loop.run()
        return core.exit_status(self.returncode)

    def forward(self, number):
        self.signal_child(number)
        return True

    def forward_interrupt(self):
        if not self.tty:
            self.signal_child(signal.SIGINT)
        return True

    def on_resize(self):
        self.resize()
        return True


def main(argv):
    args = parse_args(argv)
    connection = connect()
    if connection is None:
        return run_plain(args.command)
    runner = Runner(connection[0], connection[1], args)
    try:
        return runner.run()
    except OSError as err:
        return report_spawn_error(args.command, err)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
