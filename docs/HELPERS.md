# Helper scripts

The Python scripts in `scripts/` that feed data to the services, and how the shell keeps track of them and of the tools they need.

## The scripts

Among them `kwin_window_tracker.py`, `hardware_stats.py`, `devices.py`, `audio_*.py`, `downloads_tracker.py`, `clipboard_tracker.py`, `shortcuts.py`, `activities_bridge.py` and `kio_jobs.py`. Some run once per request, others for as long as the shell does; `LONG_RUNNING` in `scripts/helper_health.py` names the second kind.

`scripts/kwin_script.js` runs inside KWin. `kwin_window_tracker.py` loads it from its own directory.

## Adding a long-running helper

1. Register its `Process` with `HelperService.watch(id, name, proc)` in the service that starts it. `HelperService` lists them in the Health section of the About page (`island/settings/HealthSection.qml`).
2. Add the script to `LONG_RUNNING` in `scripts/helper_health.py` (tested by `tests/test_helper_health.py`), which finds leftover helpers from an earlier run.
3. Add every tool, Python module or D-Bus service it needs to `deps.json` (see below).

Try a D-Bus helper on a private bus first, with `./run.sh --sandbox`.

## Dependencies

`deps.json` lists every external tool, Python module and D-Bus service the shell uses, with the features each one supports and its package name per distro. Add an entry when a feature starts using a new one.

`scripts/check_deps.py` (`./run.sh --check`, and the welcome guide's system check) checks them, tested by `tests/test_check_deps.py`.
