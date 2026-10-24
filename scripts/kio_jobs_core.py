"""Pure parts of kio_jobs.py: turning KIO job views into activity calls. No D-Bus,
so it is tested by tests/test_kio_jobs_core.py (see docs/KIO_JOBS.md).

KIO describes a job with a property map (`title`, `descriptionValue1`, `percent`,
`speed`, `totalFiles`, ...) sent whole to requestView and in parts to update.
Jobs keeps those maps and works out which Show and Update calls the island
needs, so that a job appears once it has run for a second, ends the way KIO
says it did, and never sends more calls than the island's rate limit allows.
"""
import os
from urllib.parse import unquote, urlparse

# A job only appears once it has run this long, so quick copies never flash in the island
SHOW_AFTER_MS = 1000

# terminate()'s error code: 0 is success, KJob::KilledJobError (KIO's ERR_USER_CANCELED) a cancel
KILLED = 1

# requestView's capabilities: KJob::Killable
CAP_KILLABLE = 1

CANCEL_ACTION = ("cancel", "Cancel")
APP_CLOSED = "The app closed before the operation finished"


def format_size(n):
    """Bytes as KDE shows them: binary units, one decimal from KiB up"""
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(n)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return "%d %s" % (value, unit) if unit == "B" else "%.1f %s" % (value, unit)
        value /= 1024


def format_speed(bytes_per_second):
    return format_size(bytes_per_second) + "/s"


def file_name(location):
    """The last part of a path or URL, as the user would call the file"""
    if not location:
        return ""
    text = str(location)
    if "://" in text:
        text = unquote(urlparse(text).path)
    return os.path.basename(text.rstrip("/")) or text


def count_text(n):
    return "{:,}".format(int(n))


def title_for(props):
    """"Copying 12 files", or "Copying photo.jpg" for a single file"""
    verb = str(props.get("title") or "Working")
    files = int(props.get("totalFiles") or 0)
    if files > 1:
        return "%s %s files" % (verb, count_text(files))
    name = file_name(props.get("descriptionValue1"))
    return "%s %s" % (verb, name) if name else verb


def text_for(props):
    """The current file and the speed, or KIO's own message when it names no file"""
    parts = []
    name = file_name(props.get("descriptionValue1"))
    if name and int(props.get("totalFiles") or 0) > 1:
        parts.append(name)
    elif not name and props.get("infoMessage"):
        parts.append(str(props["infoMessage"]))
    speed = int(props.get("speed") or 0)
    if speed > 0:
        parts.append(format_speed(speed))
    return " · ".join(parts)


def progress_for(props):
    """0.0 to 1.0, or -1.0 (indeterminate) while KIO doesn't know the total yet"""
    if "percent" not in props:
        return -1.0
    known = int(props.get("totalBytes") or 0) > 0 or int(props.get("totalFiles") or 0) > 0
    percent = int(props["percent"])
    if not known and percent == 0:
        return -1.0
    return min(max(percent, 0), 100) / 100.0


def running_fields(props):
    return {"title": title_for(props), "text": text_for(props), "progress": progress_for(props)}


def end_fields(props, code, message):
    """The last Update for a job KIO ended with `code` and `message`"""
    if code == 0:
        return {"state": "done", "progress": 1.0, "text": ""}
    if code == KILLED:
        done, total = int(props.get("processedFiles") or 0), int(props.get("totalFiles") or 0)
        if total > 1:
            return {"state": "cancelled", "text": "Cancelled after %s of %s files" % (count_text(done), count_text(total))}
        return {"state": "cancelled", "text": "Cancelled"}
    error = str(message).strip() or "Failed (error %d)" % code
    return {"state": "failed", "error": error, "actions": []}


def show_delay_ms(hints):
    """How long until a new job should appear. KIO itself waits before it asks for a view,
    and says in elapsedTime how long the job has run."""
    return max(0, SHOW_AFTER_MS - int(hints.get("elapsedTime") or 0))


class Job:
    def __init__(self, number, owner, icon, capabilities, props, show_at):
        self.number = number
        self.id = "kio-%d" % number
        self.owner = owner
        self.icon = icon
        self.killable = bool(capabilities & CAP_KILLABLE)
        self.props = dict(props)
        self.show_at = show_at
        self.shown = False
        self.hidden = False      # dismissed by the user, or refused by the island
        self.sent = {}           # the fields the island has now
        self.final = None        # the end fields, once KIO has ended the job
        self.closing = False     # the end fields went out; kept a tick in case the call fails

    def show_fields(self):
        fields = dict(running_fields(self.props), priority="normal")
        if self.icon:
            fields["icon"] = self.icon
        if self.killable:
            fields["actions"] = [CANCEL_ACTION]
        return fields

    def wanted(self):
        """The fields the island should have now"""
        fields = running_fields(self.props)
        if self.final is not None:
            fields.update(self.final)
        return fields


class Jobs:
    """Every job view KIO has asked for, and what the island has been told about each.

    Times are milliseconds from any fixed clock. take_calls() returns the calls
    to make, as (method, activity id, fields), at most `budget` of them.
    """

    def __init__(self):
        self.jobs = {}
        self.next_number = 1

    def add(self, owner, icon, capabilities, hints, now):
        job = Job(self.next_number, owner, icon, capabilities, hints, now + show_delay_ms(hints))
        self.next_number += 1
        self.jobs[job.number] = job
        return job

    def get(self, number):
        return self.jobs.get(number)

    def update(self, number, props):
        job = self.jobs.get(number)
        if job is not None and job.final is None:
            job.props.update(props)

    def terminate(self, number, code, message):
        job = self.jobs.get(number)
        if job is None or job.final is not None:
            return
        if not job.shown or job.hidden:
            # Ended before it was shown, or after the user hid it: nothing to say
            del self.jobs[number]
            return
        job.final = end_fields(job.props, code, message)

    def owner_gone(self, owner):
        """The app that owns these jobs left the bus without ending them"""
        for job in [j for j in self.jobs.values() if j.owner == owner and j.final is None]:
            if job.shown and not job.hidden:
                job.final = {"state": "failed", "error": APP_CLOSED, "actions": []}
            else:
                del self.jobs[job.number]

    def by_activity(self, activity_id):
        for job in self.jobs.values():
            if job.id == activity_id:
                return job
        return None

    def cancel_requested(self, activity_id):
        """The job to cancel for the island's Cancel button, or None. It stays
        running until KIO ends it, since only KIO knows whether it stopped."""
        job = self.by_activity(activity_id)
        if job is None or job.final is not None or not job.killable:
            return None
        return job

    def dismissed(self, activity_id):
        """The user removed the activity. The job itself carries on."""
        job = self.by_activity(activity_id)
        if job is None:
            return
        if job.final is not None:
            del self.jobs[job.number]
        else:
            job.hidden = True

    def island_restarted(self):
        """The island forgot every activity: show the running jobs again, except
        those the user dismissed"""
        for job in list(self.jobs.values()):
            if job.final is not None:
                del self.jobs[job.number]
            else:
                job.shown = False
                job.sent = {}
                job.closing = False

    def call_failed(self, activity_id, method, code):
        """A call the island refused, by the error code's last part (RateLimited, NotFound, ...)"""
        job = self.by_activity(activity_id)
        if job is None:
            return
        if code in ("RateLimited", "LimitExceeded", "NoReply", "ServiceUnknown"):
            # Passing problems: send everything again on a later tick
            if method == "Show":
                job.shown = False
            job.sent = {}
            job.closing = False
        else:
            # NotFound (dismissed or expired in the island) or a refusal that would repeat
            if job.final is not None:
                del self.jobs[job.number]
            else:
                job.hidden = True

    def next_due(self, now):
        """Milliseconds until a job that waits for its first second is due, or None"""
        waits = [j.show_at - now for j in self.jobs.values() if not j.shown and not j.hidden and j.final is None]
        return max(0, min(waits)) if waits else None

    def take_calls(self, now, budget):
        calls = []
        # Ended jobs first, so a burst of progress never holds back how a job ended
        order = sorted(self.jobs.values(), key=lambda j: (j.final is None, j.number))
        for job in order:
            if len(calls) >= budget:
                break
            if job.hidden:
                if job.final is not None:
                    del self.jobs[job.number]
                continue
            if not job.shown:
                if job.final is None and now >= job.show_at:
                    fields = job.show_fields()
                    calls.append(("Show", job.id, fields))
                    job.shown = True
                    job.sent = dict(fields)
                continue
            if job.closing:
                del self.jobs[job.number]
                continue
            wanted = job.wanted()
            diff = {k: v for k, v in wanted.items() if job.sent.get(k) != v}
            if diff:
                calls.append(("Update", job.id, diff))
                job.sent.update(diff)
            if job.final is not None:
                job.closing = True
        return calls

    def visible_running(self):
        return [j for j in self.jobs.values() if j.shown and not j.hidden and j.final is None]
