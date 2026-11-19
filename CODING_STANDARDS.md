# Coding standards

Rules for writing and reviewing changes. Mechanical ones are checked by `./lint.sh` and `./test.sh` instead; these need judgement.

## Structure

- `services/*Service.qml` singletons own state and talk to the system. Views bind to them and hold no system logic.
- Colors, sizes and scale come from `services/Theme.qml`, never hardcoded values.
- Logic that needs no system goes in a plain file with its own tests: a `.js` file tested by a `tests/tst_*.qml`, or a `scripts/*_core.py` with no D-Bus tested by a `tests/test_*.py`. The service or the D-Bus script stays a thin layer over it.
- Behaviour that needs Quickshell itself (a window, a `FileView`, a service), and that a hand check could miss, gets a shell test in `tests/fixtures/` (`docs/TESTING.md`).
- Don't poll state that has a change signal. Use the first of these that fits:
  1. a native Quickshell service that signals on change (`PowerProfiles`, `UPower`, `Pipewire`, ...);
  2. an event stream, run as a long-running helper (`docs/HELPERS.md`): `udevadm monitor`, `nmcli monitor`, `busctl monitor --match`, or a script's `watch` command that listens for D-Bus signals (`scripts/dbus_watch.py`) or file changes;
  3. a file watch (`FileView` with `watchChanges`);
  4. a push from the command that makes the change.

  Polling is a last resort, for state with nothing to signal a change. Then poll only while the view that shows it is open, at the longest interval it can bear. A one-off read when a popup opens is fine.
- A window that is opened on demand (a panel, a launcher) builds its content on the first open, not at startup: a `Loader` whose `active` is set on the first `shown` and stays set, so reopening is instant and state such as the scroll position survives a close. The window reaches into it through a `content` property, null until then, and the content exposes what it needs with `property alias` or functions. Timers, data and IPC that must run while it is closed stay outside, in the window or a service. See `ClipboardWindow`, `SettingsWindow` and `DialWindow`.
- A list that also moves with the keyboard and selects the row under the pointer selects it from `onPositionChanged` through `PointerMoveGate`, not from `onEntered`: rows that scroll under a still pointer must not take the selection from the keyboard. See `DockAppPicker` and `DialMenu`.
- User config files go in `SettingsService.configDir`, never in the shell folder (`Quickshell.shellDir`), which an update or a reinstall replaces.
- When a change alters behaviour that a doc in `docs/` describes (an API, a file format, a colour mapping), update the doc in the same change.

## Privacy and safety

- Clipboard history stays in memory. The only thing written is copied images, under `$XDG_RUNTIME_DIR`, see `docs/CLIPBOARD.md`.
- Launcher expressions go through the parser in `services/launcherExtras.js`, never `eval`. Web search shortcut URLs must be http or https.
- Every change `install.sh` makes goes through `act`, so `--dry-run` stays accurate. It runs `sudo` only after a typed yes, and leaves the user's config files as they are.

## Window matching

- `DockService.findToplevels` matches windows to apps. When a desktop entry declares `StartupWMClass`, matching is exact: no substring or fuzzy match. A looser match made the Vivaldi launcher entry match Vivaldi PWA windows, so launching Vivaldi focused the PWA.
- Windows come from two sources, Wayland toplevels and the KWin script. `getMergedWindows` combines them, so match against its result.

## Launcher

- Search extras, settings pages and files appear beside or in place of the app list. The app list itself, and its order, stay as the app search made them.
- File search is done by Filehouse (`filehouse --search`). The shell reads its results and leaves the walk to it.
