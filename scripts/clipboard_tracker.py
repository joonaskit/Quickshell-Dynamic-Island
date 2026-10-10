#!/usr/bin/env python3
"""Clipboard tracker for Quickshell Island.

Runs `wl-paste --watch` and prints one JSON line per clipboard change:

  {"type": "text", "text": ..., "kind": "text"|"url", "sensitive": bool,
   "size": bytes, "chars": n, "lines": n, "time": ms}
  {"type": "files", "files": [paths], "time": ms}
  {"type": "image", "mime": "image/png", "path": file, "hash": sha1, "size": bytes, "time": ms}
  {"type": "other", "mime": "application/x-foo"}
  {"type": "secret"}   copy marked by a password manager; its content is never read
  {"type": "empty"}    nothing on the clipboard

Copied images are saved under $XDG_RUNTIME_DIR (a RAM-backed tmpfs) so the history can
show and re-copy them. The folder is emptied when the tracker starts and stops.
"""
import hashlib
import json
import math
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from urllib.parse import unquote

# Copies above this many characters are not recorded
MAX_CHARS = 200_000
# Images above this many bytes are not recorded
MAX_IMAGE_BYTES = 25 * 1024 * 1024
IMAGE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "quickshell-clipboard-images")
IMAGE_EXTENSIONS = {"image/jpeg": "jpg", "image/svg+xml": "svg", "image/x-icon": "ico"}

PASSWORD_HINT_TYPE = "x-kde-passwordManagerHint"
TEXT_TYPES = ("text/plain", "UTF8_STRING", "STRING", "TEXT")

URL_RE = re.compile(r"^(https?|ftp|file|mailto|ssh|git)://\S+$|^mailto:\S+$", re.IGNORECASE)

SECRET_PATTERNS = [
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY"),
    re.compile(r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{30,}"),
    re.compile(r"\bglpat-[A-Za-z0-9_\-]{15,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_\-]{30,}"),
    re.compile(r"\bxox[abprs]-[A-Za-z0-9\-]{10,}"),
    re.compile(r"\bsk-[A-Za-z0-9_\-]{20,}"),
    re.compile(r"\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"),
    re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|token)\s*[=:]\s*\S{6,}"),
]


def shannon_entropy(s):
    if not s:
        return 0.0
    counts = {}
    for ch in s:
        counts[ch] = counts.get(ch, 0) + 1
    n = len(s)
    return -sum(c / n * math.log2(c / n) for c in counts.values())


def looks_secret(text):
    """Heuristic: does this text look like a credential?"""
    if any(p.search(text) for p in SECRET_PATTERNS):
        return True
    s = text.strip()
    # A single long token with high entropy and mixed character classes (random keys, passwords)
    if 20 <= len(s) <= 512 and not re.search(r"\s", s) and not URL_RE.match(s):
        classes = sum(bool(re.search(p, s)) for p in (r"[a-z]", r"[A-Z]", r"[0-9]"))
        if classes >= 3 and shannon_entropy(s) >= 4.0:
            return True
    return False


def classify_text(text):
    """Returns (kind, sensitive) for a piece of copied text."""
    s = text.strip()
    kind = "url" if URL_RE.match(s) else "text"
    return kind, looks_secret(text)


def build_text_record(text, now_ms=None):
    """The record for copied text, or None when it should not be recorded."""
    if text.strip() == "" or len(text) > MAX_CHARS:
        return None
    kind, sensitive = classify_text(text)
    return {
        "type": "text",
        "text": text,
        "kind": kind,
        "sensitive": sensitive,
        "size": len(text.encode("utf-8")),
        "chars": len(text),
        "lines": text.count("\n") + (0 if text.endswith("\n") or text == "" else 1),
        "time": int(time.time() * 1000) if now_ms is None else now_ms,
    }


def parse_uri_list(raw):
    files = []
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("file://"):
            files.append(unquote(line[7:]))
    return files


def pick_image_type(types):
    """The image format to read: PNG when offered, else the first image type."""
    images = [t for t in types if t.startswith("image/")]
    if "image/png" in images:
        return "image/png"
    return images[0] if images else None


def build_image_record(data, mime, now_ms=None, directory=None):
    """Saves image bytes and returns their record, or None when empty or too large."""
    if not data or len(data) > MAX_IMAGE_BYTES:
        return None
    digest = hashlib.sha1(data).hexdigest()
    ext = IMAGE_EXTENSIONS.get(mime) or re.sub(r"[^a-z0-9]", "", mime.split("/", 1)[1].lower()) or "img"
    directory = directory or IMAGE_DIR
    os.makedirs(directory, mode=0o700, exist_ok=True)
    path = os.path.join(directory, f"{digest}.{ext}")
    if not os.path.exists(path):
        with open(path, "wb") as f:
            f.write(data)
    return {
        "type": "image",
        "mime": mime,
        "path": path,
        "hash": digest,
        "size": len(data),
        "time": int(time.time() * 1000) if now_ms is None else now_ms,
    }


def wl_paste(*args):
    """Runs wl-paste and returns its stdout bytes, or None when it fails."""
    try:
        r = subprocess.run(["wl-paste", *args], capture_output=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def snapshot():
    """Describes the current clipboard content as a record."""
    out = wl_paste("--list-types")
    types = out.decode("utf-8", "replace").split() if out else []
    if not types:
        return {"type": "empty"}
    if PASSWORD_HINT_TYPE in types:
        return {"type": "secret"}
    if "text/uri-list" in types:
        raw = wl_paste("--type", "text/uri-list")
        files = parse_uri_list(raw.decode("utf-8", "replace")) if raw else []
        if files:
            return {"type": "files", "files": files, "time": int(time.time() * 1000)}
    if any(t in TEXT_TYPES or t.startswith("text/plain") for t in types):
        raw = wl_paste("-n", "--type", "text/plain")
        if raw is None:
            return {"type": "empty"}
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            return {"type": "other", "mime": types[0]}
        record = build_text_record(text)
        return record if record else {"type": "empty"}
    image_type = pick_image_type(types)
    if image_type:
        data = wl_paste("--type", image_type)
        record = build_image_record(data, image_type) if data else None
        return record if record else {"type": "empty"}
    return {"type": "other", "mime": types[0]}


def emit(record):
    sys.stdout.write(json.dumps(record) + "\n")
    sys.stdout.flush()


def main():
    # `wl-paste --watch echo` prints one empty line per clipboard change
    shutil.rmtree(IMAGE_DIR, ignore_errors=True)
    child = subprocess.Popen(["wl-paste", "--watch", "echo"], stdout=subprocess.PIPE, text=True)

    def stop(*_):
        child.terminate()
        shutil.rmtree(IMAGE_DIR, ignore_errors=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    try:
        # wl-paste also fires once on startup, which reports the initial content
        for _ in child.stdout:
            emit(snapshot())
    except BrokenPipeError:
        # The shell is gone
        pass
    finally:
        child.terminate()
        shutil.rmtree(IMAGE_DIR, ignore_errors=True)


if __name__ == "__main__":
    main()
