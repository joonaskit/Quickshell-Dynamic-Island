# Activities API

Other apps can show short, live information in the island, such as a file copy in progress, without being part of the shell. An app publishes an **activity**: a small record describing something ongoing. The shell decides how it looks. Apps never send QML, so they can't break the island, and the look stays consistent.

The API is a D-Bus interface on the **session bus**. It works from any language. `examples/activity_client.py` is a complete Python client.

Current version: **1**. Read the `Version` property and check it before relying on anything here. A change that would break existing clients increases the version.

| | |
| --- | --- |
| Bus name | `org.quickshell.IslandActivities` |
| Object path | `/org/quickshell/IslandActivities` |
| Interface | `org.quickshell.IslandActivities1` |
| Property | `Version` (`u`, read only) |

The service lives in `scripts/activities_bridge.py`, which the shell starts. If the bus name has no owner, the island isn't running: skip the calls, and don't treat it as an error.

## Methods

| Method | Signature | Meaning |
| --- | --- | --- |
| `Show(id, fields)` | `sa{sv}` | Create an activity, or replace the one with that `id` (all fields not given go back to their defaults) |
| `Update(id, fields)` | `sa{sv}` | Change the given fields of an existing activity; the rest stay |
| `Dismiss(id)` | `s` | Remove an activity. Dismissing one that doesn't exist is fine |

`id` is chosen by the sender and only has to be unique among that sender's own activities (at most 64 characters, no `/` or control characters). Two apps can both use `copy-1`.

## Signals

| Signal | Signature | Meaning |
| --- | --- | --- |
| `ActionInvoked(id, action)` | `ss` | The user pressed one of the activity's actions |
| `Dismissed(id)` | `s` | The user dismissed the activity in the island |

Signals are sent to everyone on the bus, not just the owning app, so match on your own `id`s. Don't put anything in an `id` that you wouldn't want other apps to see.

## Fields

Every field is optional. Strings are cut to their limit (with an ellipsis), and control characters and line breaks are replaced by spaces.

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `s` | empty | Short headline, such as "Copying 12 files". At most 80 characters |
| `text` | `s` | empty | Secondary line, such as the current file name or the speed. At most 160 characters |
| `icon` | `s` | none | An icon theme name (`folder-copy`), or an absolute path to a `.png`, `.svg`, `.jpg`, `.webp` or `.xpm` file without `..` in it. A glyph is used if it can't be loaded |
| `progress` | `d` | none | `0.0` to `1.0` (larger values count as `1.0`). **Negative means indeterminate**: the total isn't known. Without it, no bar is shown |
| `priority` | `s` | `normal` | `low`, `normal` or `high`. Used to choose which activity the compact island shows |
| `state` | `s` | `running` | `running`, `done`, `cancelled` or `failed`, see below |
| `error` | `s` | empty | What went wrong, shown for a `failed` activity: which file, what error. At most 240 characters |
| `actions` | `a(ss)` or `aa{ss}` | none | Up to 3 buttons, each an `(id, label)` pair or `{"id": ..., "label": ...}`. Ids at most 32 characters, labels at most 24 |

### States

- **running**: in progress. A progress of `1.0` is *not* "done": the island never says an operation finished unless the app reports `done`.
- **done**: finished successfully. Shown briefly (4 seconds), then removed. Actions are cleared.
- **cancelled**: stopped on request. Put the final outcome in `text`, for example "Cancelled after 5 of 12 files". Shown for 6 seconds, then removed. Actions are cleared.
- **failed**: stays in the island until the user dismisses it. Put what failed in `error`. Actions are kept, so a "Retry" can be offered.

Once an activity has left `running`, `Update` can't put it back; call `Show` again for a retry.

### Cancelling

Add an action such as `("cancel", "Cancel")`. When the user presses it, the island only sends `ActionInvoked`. It doesn't change the activity: the app stops its work and then reports the outcome with `Update`, as `cancelled` (with how far it got) or `failed`. Until it does, the island keeps showing the activity as running.

## Lifetime

Activities belong to the sender's D-Bus connection. When the sender exits or crashes:

- a **running** activity becomes **failed** with the error "The app closed before the operation finished". It stays until dismissed, so the island never implies that the operation completed. Its actions are removed.
- a **failed** activity stays until dismissed (without actions).
- a **done** or **cancelled** activity runs out its usual few seconds. A script can send `done` and exit straight away.

If the island restarts, it forgets all activities. Clients that want to survive that can watch `NameOwnerChanged` for the bus name and call `Show` again for what is still running.

## Limits

The island refuses calls that break these, with a D-Bus error named `org.quickshell.IslandActivities.Error.<Code>`.

| Code | Meaning |
| --- | --- |
| `InvalidArgs` | A field of the wrong type, an unknown field, an unknown priority or state, a bad icon, a bad action |
| `NotFound` | `Update` for an id that doesn't exist (it may have been dismissed or timed out) |
| `InvalidState` | `Update` tried to set a finished activity back to `running` |
| `LimitExceeded` | More than 8 activities from one sender, or 32 in total |
| `RateLimited` | More than 20 calls per second per sender (bursts of 40 are fine). Updating progress a few times a second is plenty |

Anything on the session bus can post activities. That is acceptable for a personal desktop shell, and the limits above keep a misbehaving client from flooding it.

## What the island does with them

- **Several at once:** the compact island shows one, with a `+N` count for the others. The expanded view lists all of them (up to five rows), with their progress and actions.
- **Which one:** failed activities first, then higher `priority`, then the one that was shown (not updated) most recently. Updates don't reshuffle.
- **Against other things in the compact island:** an OSD or a notification alert (both short-lived) come first. After those: a failed activity, then a running timer or stopwatch, then other activities, then media. So a running timer hides a running activity until the timer ends, but never a failure.
- **Failures** stay in the compact island with a dismiss button until the user removes them.
- Activities are separate from notifications. Use activities for work in progress, and notifications for finished work the user may have missed.

The user can turn the compact island display off with "App Activities in Island", and the expanded view card with "App Activities", in the settings.

## Trying it

With the shell running:

```
python3 examples/activity_client.py          # a fake copy that finishes
python3 examples/activity_client.py --fail   # one that fails halfway
```

Or from a shell, with `busctl`:

```
busctl --user call org.quickshell.IslandActivities /org/quickshell/IslandActivities \
  org.quickshell.IslandActivities1 Show 'sa{sv}' demo 3 \
  title s "Hello" progress d -1 priority s normal
busctl --user call org.quickshell.IslandActivities /org/quickshell/IslandActivities \
  org.quickshell.IslandActivities1 Dismiss s demo
```

Note that `busctl` is a short-lived sender: its activity counts as abandoned as soon as the command returns, so a running one turns into a failure. For scripts, keep a connection open (for example with Python), or end with a final state.

## Implementation

- `scripts/activities_core.py`: validation, limits, lifetime and ordering, with no D-Bus. Tested in `tests/test_activities_core.py`.
- `scripts/activities_bridge.py`: the D-Bus interface. Talks to the shell with one JSON object per line: the full activity list on stdout after every change, and the user's actions and dismissals on stdin.
- `services/ActivityService.qml`: runs the bridge (restarting it if it dies) and holds the list.
- `island/CompactActivityView.qml` and `widgets/ActivitiesWidget.qml`: the compact island and the expanded view card.
