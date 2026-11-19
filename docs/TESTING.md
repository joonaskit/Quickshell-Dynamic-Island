# Testing

`./test.sh` runs three kinds of test. All of them run in CI (`.github/workflows/check.yml`).

| Kind | Files | Runs in | For |
|---|---|---|---|
| QML unit tests | `tests/tst_*.qml` | `qmltestrunner`, offscreen | Logic in plain `.js` files |
| Python tests | `tests/test_*.py` | `unittest` | The helper scripts' `*_core.py` logic, repo checks |
| Shell tests | `tests/fixtures/<name>/shell.qml` | Quickshell in a headless KWin | Behaviour of the shell's own QML files |

`qmltestrunner` cannot load files that use Quickshell types (`PanelWindow`, `FileView`, `Process`, the services). The shell tests cover those.

## Shell tests

Each fixture is a small `ShellRoot` that creates the real component it tests, drives it, and reports `RESULT pass` or `RESULT fail <reason>`. `tests/run_fixtures.sh` runs them:

```bash
tests/run_fixtures.sh
```

```bash
tests/run_fixtures.sh watched-file
```

How a run is set up:

- One `kwin_wayland --virtual` for the whole run, on its own Wayland socket and a private D-Bus with no service files, so nothing is started on demand (portals, a secrets daemon). Layer-shell windows such as the clipboard panel map in it as they do on the desktop.
- A clean environment (`env -i`) with a temporary `HOME`, `XDG_*` folders and runtime dir. Nothing from the desktop you are using reaches a fixture: not its Wayland or X display, niri's socket or the session bus. `CompositorService` sees neither KDE nor niri, so KWin- and niri-only helpers stay off.
- Each fixture gets its own directory: its `.qml` files, the repo's `qmldir` and folders linked in, and `tests/fixtures/lib` linked as `fixture`. `Quickshell.shellDir` is that directory, so `SettingsService` reads and writes a `settings.json` of its own there, never yours.
- A fixture fails when it reports a failure, exits uncleanly, runs past 20 seconds, or when its log has a `ReferenceError` or `TypeError` from any file, even when its checks passed.

The run is skipped, without failing, when `quickshell`, `kwin_wayland` or `dbus-run-session` is missing. On Fedora they come from `quickshell`, `kwin` and `dbus-daemon`.

`./lint.sh` lints each fixture laid out as it runs (`tests/run_fixtures.sh --layout DIR NAME`), since its types only resolve there.

### Writing one

Add `tests/fixtures/<name>/shell.qml`:

```qml
import QtQuick
import Quickshell
import "fixture"

ShellRoot {
    ClipboardWindow {
        id: clipboard
        modelData: Quickshell.screens[0]
    }

    Steps {
        id: steps
        steps: [
            { name: "never opened", until: () => steps.expect("content", clipboard.content, null) },
            { name: "first open", run: () => ClipboardService.windowOpen = true, until: () => clipboard.content !== null }
        ]
    }
}
```

`Steps` (`tests/fixtures/lib/Steps.qml`) runs the steps in order. Each step's `run` acts, then the step waits until `until` holds, failing after `timeout` ms (3000 by default). `expect(what, actual, expected)` fails at once with both values. `steps.work` is a directory of the fixture's own for files it writes, also in `$FIXTURE_WORK` for commands it runs.

Report results with `console.info` if you add any of your own: Quickshell does not print `console.log`.

Keep a fixture to one behaviour, and drive the component through the same properties and services the shell does. Before relying on a new fixture, break the code it covers once and see it fail.

### Fixtures

| Fixture | Covers |
|---|---|
| `watched-file` | `WatchedFile` following a file that is created, written in place, appended to, replaced by a rename (once and twice in a row), written after a rename, removed and created again |
| `clipboard-first-open` | `ClipboardWindow` building its card on the first open, fading it in, and keeping the same card across a close and reopen (`CODING_STANDARDS.md`, building windows on first open) |
