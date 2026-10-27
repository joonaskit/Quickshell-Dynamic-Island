# Quickshell Island

QML desktop shell for KDE Plasma (Wayland), built with Quickshell: a morphing top "island" bar plus a dock and app launcher. See README.md for features and requirements.

Read `CODING_STANDARDS.md` before writing code.

## Layout

- `shell.qml` is the entry point. It creates `IslandWindow` and `DockWindow` per screen and registers the IPC handlers.
- `qmldir` registers every singleton and component. Add new QML files there (`tests/test_qmldir.py` checks it). Files in subfolders (e.g. `dock/`) must `import ".."` to see the root types.
- `services/` holds the `*Service.qml` singletons and `Theme.qml`. `scripts/` holds the Python helpers they run.
- `ScreenService` decides which screens get the windows (`screenMode`: main, all or a named one). The main screen is the one KDE gives priority 1 in `kscreen-doctor -j`, else the first. `shell.qml` and `OnboardingWindow` take their screens from it.
- `island/` holds the island window, pills, clusters and views, and `island/settings/` the settings pages. `dock/` holds the dock and the launcher, `quicksettings/` the status icon popups, `widgets/` the expanded-view widgets, and `components/` small shared pieces.
- `clipboard/`, `onboarding/` and `settings/` hold the clipboard, welcome guide and settings windows.

## Docs

Read the doc for an area before changing it:

- Adding a setting, or the settings window: `docs/SETTINGS.md`
- Launcher search (calculator, settings pages, files): `docs/LAUNCHER.md`
- Status icons, pill style, tucked pills: `docs/TOP_BAR.md`
- Helper scripts, `HelperService`, `deps.json`: `docs/HELPERS.md`
- `install.sh`: `docs/INSTALLER.md`
- Clipboard history: `docs/CLIPBOARD.md`
- Welcome guide: `docs/ONBOARDING.md`
- Activities D-Bus API and `island-run`: `docs/ACTIVITIES_API.md`
- File copy progress from KIO apps: `docs/KIO_JOBS.md`
- Config export and import: `docs/CONFIG_EXPORT.md`
- KDE colour scheme: `docs/KDE_THEME.md`
- `theme.json` for companion apps: `docs/THEME.md`
- Expanded-view widgets: `docs/WIDGETS.md`
- Animations: `docs/ANIMATION_CATALOGUE.md`

## Running

- Quickshell hot-reloads on save for most QML changes, but not for everything. Icon changes (e.g. `SvgIcon`) do not reload, and edits to singleton services (e.g. `DockService`, `WindowService`) may not either, so the user must kill and start the process again (`./run.sh -k`, then `./run.sh`). Tell the user when a change needs this. If it has crashed, the user restarts it too.
- `./run.sh` starts it. Other flags: `-l` toggles the launcher, `-k` kills it, `-d` runs it as a daemon.
- The session bus is the user's live desktop. Try D-Bus helpers under `./run.sh --sandbox [COMMAND...]` (`scripts/sandbox.sh`): a private bus with its own `activities_bridge.py`, whose activity lists go to the file in `$ISLAND_SANDBOX_LOG`. `tests/test_kio_jobs_sandbox.py` uses it.
- `./test.sh` runs the unit tests and `./lint.sh` the linters; both must pass before reporting work done. CI runs both (`.github/workflows/check.yml`). UI changes are still checked by hand in the running shell.

## Config files

- `settings.json` and `dock_pinned.json` are the user's live config and are gitignored. Never overwrite or commit them.

## Git

- Commit only when the user asks.
- Keep messages concise: a short capitalized summary of the work done, with no prefixes and no body unless needed. For example: "Fix app launcher window matching".

## Agent skills

### Issue tracker

Issues live in GitHub Issues for joonaskit/Quickshell-Dynamic-Island (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.
