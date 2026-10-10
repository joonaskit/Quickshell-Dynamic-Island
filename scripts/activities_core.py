"""Logic behind the activities API (docs/ACTIVITIES_API.md), without any D-Bus.

ActivityStore validates what clients send, applies per-sender limits, tracks
the lifetime of each activity and orders them for the pill. activities_bridge.py
wraps it in the D-Bus interface; keeping the logic here lets tests/ cover it
without a bus.
"""
import math
import os
import re

API_VERSION = 1

PRIORITIES = {"low": 0, "normal": 1, "high": 2}
# running: ongoing. done / cancelled: finished, auto-dismissed after a moment.
# failed: stays until the user dismisses it.
STATES = ("running", "done", "cancelled", "failed")
TERMINAL_STATES = ("done", "cancelled", "failed")
# Terminal states that clear themselves, in seconds
AUTO_DISMISS = {"done": 4.0, "cancelled": 6.0}

MAX_ID = 64
MAX_TITLE = 80
MAX_TEXT = 160
MAX_ERROR = 240
MAX_ICON = 256
MAX_ACTIONS = 3
MAX_ACTION_ID = 32
MAX_ACTION_LABEL = 24
MAX_PER_SENDER = 8
MAX_TOTAL = 32

# Calls allowed per sender: a burst, refilled continuously
RATE_BURST = 40
RATE_PER_SECOND = 20.0

ORPHANED_MESSAGE = "The app closed before the operation finished"

ICON_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
ICON_EXTENSIONS = (".png", ".svg", ".svgz", ".jpg", ".jpeg", ".webp", ".xpm")
FIELD_NAMES = ("title", "text", "icon", "progress", "priority", "state", "error", "actions")


class ActivityError(Exception):
    """A call the API rejects. `code` becomes the D-Bus error name suffix."""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def _string(name, value, limit):
    if not isinstance(value, str):
        raise ActivityError("InvalidArgs", f"{name} must be a string")
    # Other control characters are dropped; any run of whitespace becomes one space
    value = "".join(c for c in value if c.isspace() or (c >= " " and c != "\x7f"))
    value = " ".join(value.split())
    if len(value) > limit:
        value = value[: limit - 1] + "…"
    return value


def _icon(value):
    if not isinstance(value, str):
        raise ActivityError("InvalidArgs", "icon must be a string")
    if value == "":
        return ""
    if len(value) > MAX_ICON:
        raise ActivityError("InvalidArgs", "icon is too long")
    if value.startswith("/"):
        parts = value.split("/")
        if "\0" in value or ".." in parts or not value.lower().endswith(ICON_EXTENSIONS):
            raise ActivityError("InvalidArgs", "icon path must be absolute, without '..', and an image file")
        return os.path.normpath(value)
    if not ICON_NAME.match(value):
        raise ActivityError("InvalidArgs", "icon must be an icon theme name or an absolute path")
    return value


def _progress(value):
    # bool is an int in Python; a flag is not a fraction
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ActivityError("InvalidArgs", "progress must be a number")
    if math.isnan(value) or math.isinf(value):
        raise ActivityError("InvalidArgs", "progress must be a finite number")
    # Negative means indeterminate: the total is not known
    if value < 0:
        return -1.0
    return min(float(value), 1.0)


def _actions(value):
    if not isinstance(value, (list, tuple)):
        raise ActivityError("InvalidArgs", "actions must be a list")
    if len(value) > MAX_ACTIONS:
        raise ActivityError("InvalidArgs", f"at most {MAX_ACTIONS} actions")
    result = []
    seen = set()
    for item in value:
        if isinstance(item, dict):
            action_id, label = item.get("id"), item.get("label")
        elif isinstance(item, (list, tuple)) and len(item) == 2:
            action_id, label = item
        else:
            raise ActivityError("InvalidArgs", "each action is an (id, label) pair")
        action_id = _string("action id", action_id, MAX_ACTION_ID)
        label = _string("action label", label, MAX_ACTION_LABEL)
        if not action_id or not label:
            raise ActivityError("InvalidArgs", "an action needs an id and a label")
        if action_id in seen:
            raise ActivityError("InvalidArgs", f"duplicate action id {action_id!r}")
        seen.add(action_id)
        result.append({"id": action_id, "label": label})
    return result


def validate_fields(fields):
    """Check and clean the fields of a Show or Update call. Returns only the given fields."""
    if not isinstance(fields, dict):
        raise ActivityError("InvalidArgs", "fields must be a dictionary")
    unknown = [k for k in fields if k not in FIELD_NAMES]
    if unknown:
        raise ActivityError("InvalidArgs", "unknown field: " + ", ".join(sorted(map(str, unknown))))
    clean = {}
    for name, value in fields.items():
        if name == "title":
            clean[name] = _string(name, value, MAX_TITLE)
        elif name == "text":
            clean[name] = _string(name, value, MAX_TEXT)
        elif name == "error":
            clean[name] = _string(name, value, MAX_ERROR)
        elif name == "icon":
            clean[name] = _icon(value)
        elif name == "progress":
            clean[name] = _progress(value)
        elif name == "priority":
            if value not in PRIORITIES:
                raise ActivityError("InvalidArgs", "priority must be low, normal or high")
            clean[name] = value
        elif name == "state":
            if value not in STATES:
                raise ActivityError("InvalidArgs", "state must be one of " + ", ".join(STATES))
            clean[name] = value
        elif name == "actions":
            clean[name] = _actions(value)
    return clean


def validate_id(activity_id):
    if not isinstance(activity_id, str) or not activity_id:
        raise ActivityError("InvalidArgs", "id must be a non-empty string")
    if len(activity_id) > MAX_ID or "/" in activity_id or any(c < " " for c in activity_id):
        raise ActivityError("InvalidArgs", f"id must be at most {MAX_ID} characters, with no '/' or control characters")
    return activity_id


class ActivityStore:
    def __init__(self, clock):
        self._clock = clock
        self._items = {}  # (sender, id) -> activity dict
        self._buckets = {}  # sender -> [tokens, last refill time]
        self._seq = 0

    # -- calls from clients ------------------------------------------------

    def show(self, sender, activity_id, fields):
        """Create an activity, or replace the one with the same id."""
        self._rate_limit(sender)
        validate_id(activity_id)
        clean = validate_fields(fields)
        key = (sender, activity_id)
        existing = self._items.get(key)
        if existing is None:
            if sum(1 for s, _ in self._items if s == sender) >= MAX_PER_SENDER:
                raise ActivityError("LimitExceeded", f"at most {MAX_PER_SENDER} activities per sender")
            if len(self._items) >= MAX_TOTAL:
                raise ActivityError("LimitExceeded", "too many activities")
        self._seq += 1
        now = self._clock()
        item = {
            "sender": sender,
            "id": activity_id,
            "title": "",
            "text": "",
            "icon": "",
            "progress": None,
            "priority": "normal",
            "state": "running",
            "error": "",
            "actions": [],
            "seq": existing["seq"] if existing else self._seq,
            "shownAt": now,
            "updatedAt": now,
            "terminalAt": None,
        }
        item.update(clean)
        self._enter_state(item)
        self._items[key] = item
        return item

    def update(self, sender, activity_id, fields):
        """Change fields of an existing activity. Fields not given stay as they are."""
        self._rate_limit(sender)
        validate_id(activity_id)
        clean = validate_fields(fields)
        item = self._items.get((sender, activity_id))
        if item is None:
            raise ActivityError("NotFound", f"no activity {activity_id!r}")
        if (item["state"] in TERMINAL_STATES and clean.get("state", item["state"]) == "running"):
            raise ActivityError("InvalidState", "a finished activity can't resume; call Show again")
        previous = item["state"]
        item.update(clean)
        item["updatedAt"] = self._clock()
        if item["state"] != previous:
            self._enter_state(item)
        return item

    def dismiss(self, sender, activity_id):
        """Remove an activity. Returns whether it existed; dismissing a missing one is fine."""
        self._rate_limit(sender)
        validate_id(activity_id)
        return self._items.pop((sender, activity_id), None) is not None

    # -- calls from the shell ----------------------------------------------

    def dismiss_key(self, key):
        """Remove an activity on the user's behalf. Returns it, or None if it is gone."""
        return self._items.pop(self.split_key(key), None)

    def get_key(self, key):
        return self._items.get(self.split_key(key))

    @staticmethod
    def make_key(sender, activity_id):
        return f"{sender}/{activity_id}"

    @staticmethod
    def split_key(key):
        sender, _, activity_id = str(key).partition("/")
        return (sender, activity_id)

    # -- lifetime ----------------------------------------------------------

    def sender_gone(self, sender):
        """The sender left the bus. Returns True if anything changed.

        One that was still running did not finish, so it becomes a failed one
        that stays until dismissed: the pill must not look as if the operation
        completed, nor just vanish. Ones that had finished stay for their usual
        moment, since a script may well send "done" and exit straight away.
        """
        changed = False
        self._buckets.pop(sender, None)
        for item in [i for k, i in self._items.items() if k[0] == sender]:
            changed = True
            if item["state"] == "running":
                item["state"] = "failed"
                item["error"] = item["error"] or ORPHANED_MESSAGE
                item["updatedAt"] = self._clock()
                self._enter_state(item)
            # Nobody is left to answer actions or to be told about a dismissal
            item["actions"] = []
            item["orphaned"] = True
        return changed

    def senders(self):
        return {k[0] for k in self._items if not self._items[k].get("orphaned")}

    def expire(self):
        """Drop finished activities that are due. Returns the dropped ones."""
        now = self._clock()
        dropped = []
        for key, item in list(self._items.items()):
            delay = AUTO_DISMISS.get(item["state"])
            if delay is not None and item["terminalAt"] is not None and now - item["terminalAt"] >= delay:
                del self._items[key]
                dropped.append(item)
        return dropped

    def next_expiry(self):
        """Seconds until the next auto-dismiss is due, or None if none is pending."""
        now = self._clock()
        due = [
            AUTO_DISMISS[i["state"]] - (now - i["terminalAt"])
            for i in self._items.values()
            if i["state"] in AUTO_DISMISS and i["terminalAt"] is not None
        ]
        return max(0.0, min(due)) if due else None

    # -- output ------------------------------------------------------------

    def ordered(self):
        """Activities in the order the pill should favour them.

        Failed ones first, then higher priority, then the one shown most recently.
        The first entry is what the pill shows; the rest are listed in the expanded view.
        """
        return sorted(
            self._items.values(),
            key=lambda i: (i["state"] != "failed", -PRIORITIES[i["priority"]], -i["seq"]),
        )

    def snapshot(self):
        """Everything the shell needs, as plain JSON-able data."""
        return [self._export(i) for i in self.ordered()]

    def _export(self, item):
        return {
            "key": self.make_key(item["sender"], item["id"]),
            "id": item["id"],
            "title": item["title"],
            "text": item["text"],
            "icon": item["icon"],
            "progress": item["progress"],
            "priority": item["priority"],
            "state": item["state"],
            "error": item["error"],
            "actions": item["actions"],
            "orphaned": bool(item.get("orphaned")),
        }

    # -- internals ---------------------------------------------------------

    def _enter_state(self, item):
        if item["state"] in TERMINAL_STATES:
            item["terminalAt"] = self._clock()
            # A finished activity can't be cancelled; buttons would only mislead
            if item["state"] != "failed":
                item["actions"] = []
        else:
            item["terminalAt"] = None

    def _rate_limit(self, sender):
        now = self._clock()
        tokens, last = self._buckets.get(sender, (float(RATE_BURST), now))
        tokens = min(float(RATE_BURST), tokens + (now - last) * RATE_PER_SECOND)
        if tokens < 1.0:
            self._buckets[sender] = (tokens, now)
            raise ActivityError("RateLimited", "too many calls; slow down")
        self._buckets[sender] = (tokens - 1.0, now)
