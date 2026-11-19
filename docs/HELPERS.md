# Helper scripts

The Python scripts in `scripts/` that feed data to the services, and how the shell keeps track of them and of the tools they need.

## The scripts

Among them `kwin_window_tracker.py`, `hardware_stats.py`, `devices.py`, `downloads_tracker.py`, `clipboard_tracker.py`, `shortcuts.py`, `niri_binds.py`, `activities_bridge.py` and `kio_jobs.py`. Some run once per request, others for as long as the shell does; `LONG_RUNNING` in `scripts/helper_health.py` names the second kind.

`gamemode.py`, `kdeconnect.py` and `downloads_tracker.py` read once when called plainly (a popup opening, the Downloads stack's refresh), and keep running with `watch`, printing a JSON line each time the state changes. The first two run their read again on any D-Bus signal from their service, or when it appears on or leaves the bus (`scripts/dbus_watch.py`); the third on any change in the downloads folder (a Gio file monitor). Each waits for a short gap so a burst of changes gives one read, and prints nothing when the state is unchanged. They run only while their widget or the dock's Downloads item is on. Night Light runs `busctl monitor --match` on KWin's Night Light object the same way. See "Don't poll" in `CODING_STANDARDS.md`.

`top_processes.py` runs only while the dial's hardware page is open (`HardwareStatsService.watchProcesses`); if the shell goes, its next write ends it, so it is not in `LONG_RUNNING`.

`scripts/kwin_script.js` runs inside KWin. `kwin_window_tracker.py` loads it from its own directory, and is only started under KDE (`CompositorService.isKde`).

## Adding a long-running helper

1. Start it with a `HelperProcess` (`components/HelperProcess.qml`) in the service that owns it, giving its `helperId`, `helperName`, a `restartDelay` if the default doesn't suit, and `wanted` if it only runs some of the time. It restarts the helper when it exits, backs off if it keeps dying right away (`services/restartDelay.js`), and registers with `HelperService.watch`. `HelperService` lists them in the Health section of the About page (`island/settings/HealthSection.qml`).
2. Add the script to `LONG_RUNNING` in `scripts/helper_health.py` (tested by `tests/test_helper_health.py`), which finds leftover helpers from an earlier run.
   Step 2 is for scripts under `scripts/`. A plain command run through `Process` (`udevadm monitor` in `BrightnessService`, `nmcli monitor` in `NetworkService`, `busctl monitor` in `NightLightService`) is left out on purpose: its command line is not ours, so a scan would match the same command run by hand or by another program, and `--kill` would end it. These monitors also end on their own once the shell is gone: they only write when something changes, and the first write to the closed pipe kills them. Until then a leftover is idle and harmless. Still do step 1 for them, so the Health section shows whether they are running.
3. Add every tool, Python module or D-Bus service it needs to `deps.json` (see below).

Try a D-Bus helper on a private bus first, with `./run.sh --sandbox`.

## Dependencies

`deps.json` lists every external tool, Python module, D-Bus service and socket service the shell uses, with the features each one supports and its package name per distro. Add an entry when a feature starts using a new one.

`scripts/check_deps.py` (`./run.sh --check`, and the welcome guide's system check) checks them, tested by `tests/test_check_deps.py`.
