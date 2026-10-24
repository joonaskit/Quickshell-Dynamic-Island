# Coding standards

Rules for writing and reviewing changes. Mechanical ones are checked by `./lint.sh` and `./test.sh` instead; these need judgement.

## Structure

- `services/*Service.qml` singletons own state and talk to the system. Views bind to them and hold no system logic.
- Colors, sizes and scale come from `services/Theme.qml`, never hardcoded values.
- Logic that needs no system goes in a plain file with its own tests: a `.js` file tested by a `tests/tst_*.qml`, or a `scripts/*_core.py` with no D-Bus tested by a `tests/test_*.py`. The service or the D-Bus script stays a thin layer over it.
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
