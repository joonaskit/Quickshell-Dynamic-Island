# Expanded-view widgets

The widgets in the expanded island (calendar, timer, media, audio and display controls) live in `widgets/`. `widgets/WidgetRegistry.qml` lists them in display order. `island/ExpandedView.qml` builds itself from that list, and the "Expanded island cards" settings page generates one toggle per entry.

## Adding a widget

1. Create `widgets/MyWidget.qml` and register it in `qmldir`.
2. Add a `Component { id: myComponent; MyWidget {} }` and an entry to `widgets` in `WidgetRegistry.qml`.

The settings toggle, the saved on/off state and the layout follow from the entry.

## Registry entry

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Stable key, used in `settings.json`. Don't rename it once released |
| `title` | yes | Settings toggle title |
| `description` | yes | Settings toggle description, also used by settings search |
| `icon` | yes | `SvgIcon` name for the settings toggle |
| `iconColor` | yes | Settings toggle icon color, usually a `Theme.accent*` color |
| `group` | yes | `"cards"` or `"controls"`, see Layout |
| `defaultEnabled` | yes | Whether the widget is shown when the user has no saved setting for it |
| `component` | yes | The `Component` that creates the widget |
| `available` | no | `function(host)` returning whether the widget has anything to show, for example whether a media player is active. Without it the widget is always available |

A widget is shown when the user has it enabled and `available(host)` returns true. `available` is called inside a binding, so any properties it reads (`host.player`, service properties) re-evaluate it when they change.

## Widget interface

A widget is an `Item` that:

- sets `implicitHeight` to its content height. The host sets its width.
- optionally declares `property var host: null`. If it does, the expanded view sets it to itself after loading. The host exposes `currentTime` (the current time, as a `date`) and `player` (the active MPRIS player, or `null`). Bind to these with a fallback, for example `property var player: host ? host.player : null`, so the widget still works on its own.

Widgets are created once and kept alive while hidden, so their state (such as the timer tab) survives toggling them off and on.

## Layout

- `"cards"` widgets are stacked in registry order, separated by hairline dividers.
- `"controls"` widgets come after the cards, stacked closely in a single section.
- A divider is drawn above each visible section except the first.

## Settings

Enabled state is stored as one map in `settings.json`:

```json
"widgets": {
  "calendar": true,
  "timer": true,
  "media": false
}
```

Ids missing from the map use `defaultEnabled`. Older configs used one key per widget (`showExpandedCalendar` and so on). `SettingsService` reads those when a widget has no entry in the map, and the next save writes the map instead. The key mapping is in `services/settingsMigration.js`, tested in `tests/tst_settingsMigration.qml`.
