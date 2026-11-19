#!/usr/bin/env python3
"""A stand-in for niri's IPC socket, for the shell tests (tests/run_fixtures.sh starts it
for a fixture with a `niri` file in its folder). See docs/TESTING.md.

    fake_niri.py SOCKET ACTION_LOG [RECORDING...]

- "EventStream" is answered with the recordings in tests/data/niri/ (by name, default
  startup then session), one event per line, and the connection stays open.
- An action ({"Action": ...}) is written to ACTION_LOG, one JSON line each, and answered
  {"Ok": "Handled"}.
- "Workspaces", "Windows" and "FocusedOutput" are answered from the recording; any other
  request gets {"Err": ...}, as niri answers one it cannot parse.
- SIGUSR1 closes the event streams, as when niri restarts; the shell then reconnects.
"""
import json
import os
import selectors
import signal
import socket
import sys

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "niri")


def load(names):
    lines = []
    for name in names:
        with open(os.path.join(DATA, name + ".jsonl"), encoding="utf-8") as f:
            lines += [line.rstrip("\n") for line in f if line.strip()]
    return lines


def snapshot(lines):
    """The workspaces and windows the recording's first full lists give."""
    workspaces, windows = [], []
    for line in lines:
        event = json.loads(line)
        if "WorkspacesChanged" in event and not workspaces:
            workspaces = event["WorkspacesChanged"]["workspaces"]
        if "WindowsChanged" in event and not windows:
            windows = event["WindowsChanged"]["windows"]
    return workspaces, windows


def reply(request, workspaces, windows):
    if request == "Workspaces":
        return {"Ok": {"Workspaces": workspaces}}
    if request == "Windows":
        return {"Ok": {"Windows": windows}}
    if request == "FocusedOutput":
        name = next((w["output"] for w in workspaces if w.get("is_focused")), None)
        return {"Ok": {"FocusedOutput": {"name": name} if name else None}}
    if isinstance(request, dict) and "Action" in request:
        return {"Ok": "Handled"}
    return {"Err": "error parsing request"}


def main(argv):
    path, log_path = argv[1], argv[2]
    lines = load(argv[3:] or ["startup", "session"])
    workspaces, windows = snapshot(lines)

    if os.path.exists(path):
        os.unlink(path)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(path)
    server.listen(16)
    server.setblocking(False)

    sel = selectors.DefaultSelector()
    sel.register(server, selectors.EVENT_READ)
    buffers = {}
    streams = set()
    drop = []

    signal.signal(signal.SIGUSR1, lambda *_: drop.append(True))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    def close(conn):
        sel.unregister(conn)
        buffers.pop(conn, None)
        streams.discard(conn)
        conn.close()

    while True:
        for key, _ in sel.select(timeout=0.1):
            if key.fileobj is server:
                conn, _addr = server.accept()
                sel.register(conn, selectors.EVENT_READ)
                buffers[conn] = b""
                continue
            conn = key.fileobj
            try:
                data = conn.recv(65536)
            except OSError:
                data = b""
            if not data:
                close(conn)
                continue
            buffers[conn] += data
            while b"\n" in buffers.get(conn, b""):
                raw, buffers[conn] = buffers[conn].split(b"\n", 1)
                try:
                    request = json.loads(raw)
                except ValueError:
                    request = None
                if request == "EventStream":
                    conn.sendall(("\n".join(lines) + "\n").encode())
                    streams.add(conn)
                    continue
                if isinstance(request, dict) and "Action" in request:
                    with open(log_path, "a", encoding="utf-8") as f:
                        f.write(json.dumps(request, separators=(",", ":")) + "\n")
                conn.sendall((json.dumps(reply(request, workspaces, windows)) + "\n").encode())
        if drop:
            drop.clear()
            for conn in list(streams):
                close(conn)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
