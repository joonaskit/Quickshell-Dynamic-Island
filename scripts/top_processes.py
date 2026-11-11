#!/usr/bin/env python3
"""Prints the busiest programs every two seconds, as one JSON line:
{"processes": [{"name", "cpu", "memMb"}, ...]}.

HardwareStatsService runs it only while the dial's hardware page is open. If the shell
goes away, the next write to the closed pipe ends it.
"""
import json
import os
import signal
import sys
import time

import top_processes_core as core

INTERVAL = 2.0
COUNT = 8


def sample():
    out = {}
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open("/proc/" + entry + "/stat", "r") as f:
                parsed = core.parse_stat(f.read())
        except OSError:
            continue
        if parsed is not None:
            out[int(entry)] = parsed
    return out


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    clock_ticks = os.sysconf("SC_CLK_TCK")
    page_size = os.sysconf("SC_PAGE_SIZE")
    cpus = os.cpu_count() or 1
    prev = sample()
    prev_time = time.monotonic()
    while True:
        time.sleep(INTERVAL)
        curr = sample()
        now = time.monotonic()
        programs = core.group(prev, curr, now - prev_time, clock_ticks, cpus, page_size)
        prev, prev_time = curr, now
        try:
            sys.stdout.write(json.dumps({"processes": core.rank(programs, COUNT)}) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            sys.exit(0)


if __name__ == "__main__":
    main()
