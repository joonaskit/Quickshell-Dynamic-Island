"""Pure parts of island_run.py: reading progress out of a command's output and
describing how it ended. No D-Bus, so it is tested by tests/test_island_run_core.py."""
import re
import signal

# Colour codes and cursor movement (CSI), and window-title strings (OSC)
ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")
PERCENT = re.compile(r"(\d{1,3}(?:\.\d+)?)\s*%")
# "[3/12]" as printed by dnf, ninja, make and many build tools
FRACTION = re.compile(r"\[\s*(\d+)\s*/\s*(\d+)\s*\]")

TITLE_LIMIT = 80


def strip_ansi(text):
    return ANSI.sub("", text)


def parse_percent(line):
    """The last percentage in the line as 0.0 to 1.0, or None. Values over 100% are ignored."""
    found = None
    for match in PERCENT.finditer(line):
        value = float(match.group(1))
        if value <= 100.0:
            found = value / 100.0
    return found


def parse_fraction(line):
    """The last "[done/total]" in the line as 0.0 to 1.0, or None."""
    found = None
    for match in FRACTION.finditer(line):
        done, total = int(match.group(1)), int(match.group(2))
        if 0 < total and done <= total:
            found = done / total
    return found


def parse_auto(line):
    value = parse_percent(line)
    return value if value is not None else parse_fraction(line)


def parse_none(line):
    return None


PARSERS = {
    "auto": parse_auto,
    "percent": parse_percent,
    "fraction": parse_fraction,
    "none": parse_none,
}


def split_output(buffer, chunk):
    """Add a chunk of output to the unfinished text before it. Returns (complete lines, unfinished text).

    Progress bars redraw one line with a carriage return, so both \\r and \\n end a line.
    """
    text = strip_ansi(buffer + chunk)
    parts = re.split(r"[\r\n]+", text)
    return [p for p in parts[:-1] if p.strip()], parts[-1]


def default_title(command):
    """"rsync -a src dst" for the command line, kept to what the island shows."""
    title = " ".join(command)
    return title if len(title) <= TITLE_LIMIT else title[:TITLE_LIMIT - 1] + "…"


def describe_exit(title, returncode, last_line=""):
    """The final activity fields for a command that ended with `returncode`.

    A negative code is the signal that killed it. Stopping a command (Ctrl+C,
    SIGTERM, or the island's Cancel button) is "cancelled", every other
    non-zero end is "failed".
    """
    if returncode == 0:
        return {"state": "done", "progress": 1.0, "text": ""}
    if returncode < 0:
        number = -returncode
        if number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            return {"state": "cancelled", "text": "Stopped"}
        try:
            name = signal.Signals(number).name
        except ValueError:
            name = "signal %d" % number
        reason = "Killed by " + name
    else:
        reason = "Exited with code %d" % returncode
    error = reason + (": " + last_line.strip() if last_line.strip() else "")
    return {"state": "failed", "error": error}


def exit_status(returncode):
    """The wrapper's own exit code: the command's, or 128 + signal like a shell."""
    return 128 - returncode if returncode < 0 else returncode
