# Expanded-view widgets

The widgets in the expanded island (calendar, timer, media, audio and display controls) live in `widgets/`. `widgets/WidgetRegistry.qml` lists them in their default display order. `island/ExpandedView.qml` builds itself from that list, and the "Expanded island cards" section of the Island settings generates one row per entry, with a toggle and move up/down buttons.

## Adding a widget

1. Create `widgets/MyWidget.qml` and register it in `qmldir`.
2. Add an entry to `widgets` in `WidgetRegistry.qml`, with `"source": Qt.resolvedUrl("MyWidget.qml")`.

The settings row, the saved on/off state, the order and the layout follow from the entry.

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
| `source` | yes | URL of the widget's QML file, as `Qt.resolvedUrl("MyWidget.qml")` |
| `available` | no | `function(host)` returning whether the widget has anything to show, for example whether a media player is active. Without it the widget is always available |

The registry holds file URLs rather than `Component`s on purpose. The expanded view loads each file itself, so a widget's context belongs to the view. A `Component` declared in the registry would tie the widget to the singleton's context, which is torn down before the view on hot reload and leaves the widget's bindings evaluating to `undefined` (#33).

A widget is shown when the user has it enabled and `available(host)` returns true. `available` is called inside a binding, so any properties it reads (`host.player`, service properties) re-evaluate it when they change.

## Widget interface

A widget is an `Item` that:

- sets `implicitHeight` to its content height. The host sets its width.
- optionally declares `property var host: null`. If it does, the expanded view sets it to itself after loading. The host exposes `currentTime` (the current time, as a `date`) and `player` (the active MPRIS player, or `null`). Bind to these with a fallback, for example `property var player: host ? host.player : null`, so the widget still works on its own.

Widgets are created once and kept alive while hidden, so their state (such as the timer tab) survives toggling them off and on. Changing the order rebuilds them, which resets that state.

## Layout

- `"cards"` widgets are stacked in the user's order (registry order by default), separated by hairline dividers.
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

The order is stored as a list of ids:

```json
"widgetOrder": ["media", "calendar", "timer", "activities", "volume", "brightness", "audioOutput", "appMixer"]
```

An empty or missing list means registry order. Ids missing from the list (a widget added later) go at the end, in registry order, and unknown ids are dropped. A widget moves only within its group, so the list can hold both groups in any mix and each group reads its own ids in sequence. "Reset to defaults" clears the list. `SettingsService.orderedWidgets` is the registry in that order, and the reading and moving logic is in `settingsMigration.js` with the widget states.
