# Clipboard history

The clipboard history window is in `clipboard/`. `ClipboardService` fills it from `scripts/clipboard_tracker.py`, and the history logic is in `services/clipboardHistory.js`.

## Storage

History stays in memory only and is gone when the shell stops.

The one exception is copied images: the tracker saves them under `$XDG_RUNTIME_DIR` (a tmpfs), deletes each one when its entry goes, and wipes the folder when it starts and when it stops.
