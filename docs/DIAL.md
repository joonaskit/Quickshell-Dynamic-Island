# Category dial launcher (experimental)

A disc that grows out of the clock pill: categories on an inner ring, apps on an outer arc. Design reference in `desing/`. It sits beside the dock launcher, not in place of it.

- **Open:** left-click the clock pill, or `quickshell -p <dir> ipc call dial toggle`. Right-click the pill expands it instead. An alerting notification still opens on click.
- **Files:** `dial/dialLogic.js` (geometry, categories, lists; tested by `tests/tst_dialLogic.qml`), `dial/DialService.qml` (state), `dial/DialWindow.qml` (view, one per screen).
- **Turn:** wheel inside 288 px of the pill centre turns the ring, outside it the arc. Left/Right move along the arc, Up/Down change category, Enter launches, Ctrl+P pins, Esc closes.
- **Pins:** `dial_pinned.json` (gitignored), a list of app ids. Separate from the dock's pins.
- **Recent and Frequent:** read from the dock launcher's `launcher_usage.json` (`DockService.usageStats`), 16 each. A dial launch is recorded there too.
- **Launch:** goes through `WindowService.launchEntry`. Terminal apps are wrapped in `konsole -e`.
- **Search:** typing in the field under the pill swaps the category ring for four scopes with counts (Everything, Apps, Settings, Files). The best hit sits in the bottom slot, the rest alternate right and left. Up/Down change scope, Esc clears the text and then closes. Ranking is name prefix, name substring, generic name, then most launched (`matchApps`).
  - Settings come from `SettingsPagesService` (two letters or more), the same pages as the dock launcher's column.
  - Files come from `FileSearchService` (Filehouse), three letters or more, after 150 ms. They search whether or not the dock launcher's File Search setting is on, and the Files scope is empty if Filehouse is missing. The files of the last search stay on the arc until new ones arrive, and a file is only opened when its results belong to the text typed.
  - Only apps can be pinned.
- **Not built yet:** `uiScale` polish, reduced-motion behaviour.
