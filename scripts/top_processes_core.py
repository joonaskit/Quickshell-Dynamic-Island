"""Pure parts of top_processes.py: reading /proc/<pid>/stat lines and ranking programs.

Processes are grouped by their command name, so a browser's many processes count as one
program, as a dock user would think of it.
"""


def parse_stat(text):
    """(name, cpu ticks, rss pages) from a /proc/<pid>/stat line, or None.

    The name sits in parentheses and may itself hold spaces and parentheses, so the
    fields are read after its last ")".
    """
    start = text.find("(")
    end = text.rfind(")")
    if start < 0 or end < start:
        return None
    fields = text[end + 2:].split()
    # After the name: state is fields[0], utime and stime are stat fields 14 and 15,
    # rss is field 24 (1-based, counting pid and name)
    try:
        ticks = int(fields[11]) + int(fields[12])
        rss = int(fields[21])
    except (IndexError, ValueError):
        return None
    return text[start + 1:end], ticks, rss


def group(prev, curr, elapsed, clock_ticks, cpus, page_size):
    """Programs as {name: {"cpu": percent of all cores, "memMb": resident MB}}.

    `prev` and `curr` map pid to (name, ticks, rss pages) from two samples `elapsed`
    seconds apart. A pid only in `curr` counts its CPU from zero only if it is new, which
    would overstate it, so new pids add memory but no CPU. Kernel threads (no memory) are
    left out.
    """
    capacity = elapsed * clock_ticks * max(1, cpus)
    programs = {}
    for pid, (name, ticks, rss) in curr.items():
        if rss <= 0:
            continue
        entry = programs.setdefault(name, {"cpu": 0.0, "memMb": 0.0})
        entry["memMb"] += rss * page_size / (1024.0 * 1024.0)
        before = prev.get(pid)
        if before is not None and before[0] == name and capacity > 0:
            entry["cpu"] += max(0, ticks - before[1]) * 100.0 / capacity
    return programs


def rank(programs, count):
    """The top `count` programs by CPU and the top `count` by memory, each listed once,
    as [{"name", "cpu", "memMb"}] rounded for display."""
    names = sorted(programs, key=lambda n: -programs[n]["cpu"])[:count]
    for name in sorted(programs, key=lambda n: -programs[n]["memMb"])[:count]:
        if name not in names:
            names.append(name)
    return [{
        "name": name,
        "cpu": round(programs[name]["cpu"], 1),
        "memMb": int(round(programs[name]["memMb"])),
    } for name in names]
