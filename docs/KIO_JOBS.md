# File copy progress from KDE apps

Copies, moves and deletes started in Dolphin or any other KIO app show their progress in the island as [activities](ACTIVITIES_API.md): the name of the operation, the current file, the speed and a progress bar, with a Cancel button. It is the "Show File Copy Progress" setting (`kioJobActivities`), on by default, under App Activities in the Island settings.

## How it works

KIO reports each job to whatever owns two names on the session bus, `org.kde.JobViewServer` and `org.kde.kuiserver`. Plasma's notification server owns them while it runs. The shell runs its own notification server, so nothing else does, and KIO apps fall back to a progress window of their own.

`scripts/kio_jobs.py` (started by `KioJobsService`) takes both names and forwards every job through the Activities API, as an ordinary client of it. While it holds them, KIO apps leave their own progress window out. It only runs while the setting is on and App Activities are shown somewhere (in the compact island or as the expanded card), so KIO's jobs are never left with no progress display at all. If it stops, the names are free again and the apps go back to their own window.

It never takes the names from another program: if one has them, it waits in the bus's queue (the Health section shows "Waiting") and takes over when that program exits. It also gives them up to a program that asks to replace it.

## What KIO sends

Seen on the bus with KIO 6 (Plasma 6.7):

1. Introspect `/JobViewServer`, then `org.kde.kuiserver.requiresJobTracker() → b`. The helper answers `false`, so KIO adds no progress window of its own.
2. `org.kde.JobViewServerV2.requestView(s desktopEntry, i capabilities, a{sv} hints) → o`, about half a second after the job starts. The hints hold the job's properties so far. Capability 1 means it can be cancelled.
3. `org.kde.JobViewV3.update(a{sv})` on the returned path, with only the properties that changed: `title` ("Copying"), `descriptionValue1` and `descriptionValue2` (source and destination of the current file), `percent`, `processedBytes`/`totalBytes`, `processedFiles`/`totalFiles`, `speed` (bytes per second), `elapsedTime` (ms) and `infoMessage`.
4. `org.kde.JobViewV3.terminate(u errorCode, s errorMessage, a{sv})`. Code 0 is success, 1 (`KJob::KilledJobError`) a cancel, anything else an error with `errorMessage` as its text.

The view sends the signal `cancelRequested` for the island's Cancel button, and KIO then ends the job with code 1. `suspendRequested` and `resumeRequested` exist but are not offered.

## What the island shows

| | |
| --- | --- |
| Title | KIO's title and the file count, "Copying 240 files", or the file name for a single file |
| Text | The current file and the speed, "photo-0042.jpg · 14.4 MiB/s". No time estimate, as KIO's jumps around |
| Progress | KIO's percentage, indeterminate until it knows the total |
| Icon | The app's icon, from its desktop entry |
| Cancel | For jobs that can be cancelled. The activity stays running until KIO ends the job |

- A job only appears once it has run for a second (counting the time KIO already waited), so quick copies never flash in the island. A job that ends before then shows nothing.
- Success is `done`. A cancel is `cancelled`, with how far it got ("Cancelled after 120 of 240 files"). An error is `failed` with KIO's message, and stays until dismissed.
- An app that leaves the bus without ending its job (it crashed or was killed) fails the job with "The app closed before the operation finished".
- An error before the job has run for half a second never reaches the helper; the app shows its own error message.
- No notification is posted when a job ends.
- Dismissing a running job only hides it: the copy carries on.
- Stopping the helper dismisses its running jobs, so the island doesn't report copies that are still going as failed.

All jobs go through one connection, so the helper sends at most 4 calls every 250 ms, well under the Activities API's limit of 20 a second per app, with job endings first.

## Trying it

With the shell running:

```
python3 examples/kio_job_client.py           # a fake Dolphin copy of 240 files
python3 examples/kio_job_client.py --fail    # ends with an error halfway
python3 examples/kio_job_client.py --crash   # the app exits halfway
kioclient --interactive copy ~/big-folder /some/other/disk/
```

Without the shell, and without taking the names from the desktop, run it on a private bus. The activity lists the island would get go to the file in `$ISLAND_SANDBOX_LOG`:

```
./run.sh --sandbox
python3 scripts/kio_jobs.py &
python3 examples/kio_job_client.py --fail
cat "$ISLAND_SANDBOX_LOG"
```

`tests/test_kio_jobs_sandbox.py` runs a finished, a failed and a crashed job this way.

## Implementation

- `scripts/kio_jobs_core.py`: the property mapping, the one second delay, how jobs end and which calls go to the island when. No D-Bus. Tested in `tests/test_kio_jobs_core.py`.
- `scripts/kio_jobs.py`: the D-Bus server objects and the Activities API client. Prints `{"type": "status", "state": "active" | "waiting"}` for `KioJobsService`.
- KF5 apps use an older interface (`org.kde.JobViewServer.requestView(ssi)` and `org.kde.JobViewV2`), which is not implemented. Their calls are refused, and it is untested whether they then show a window of their own.
