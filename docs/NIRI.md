# niri (experimental)

The shell is built for KDE Plasma. Under niri the bar, dock, launcher and dial work, and the virtual desktops pill shows niri's workspaces. The KDE parts are left out: Night Light, KDE colour schemes, System Settings pages and the 60 Hz on battery switch (`kscreen-doctor`). Buttons that would open a KDE settings module are hidden; where [niri-settings](https://github.com/joonaskit/niri-settings) has the page, they open it instead.

## Dependencies

Entries in `deps.json` that only KDE uses (KWin, `kscreen-doctor`, `kreadconfig6`, `plasma-apply-colorscheme`) say `"desktops": ["kde"]`, so `./run.sh --check` does not report them missing under niri. niri's own are `niri` (the Shortcuts tab checks every edit with `niri validate`), `xdg-terminal-exec` (terminal apps) and `niri-settings` (optional: niri's own settings). `tests/test_kde_commands.py` fails when a QML file runs a KDE-only command without a check that keeps it from running elsewhere; its `ALLOWED` list says how each is kept. See `docs/HELPERS.md`.

## How the compositor is told

`CompositorService.name` is `kde`, `niri` or `other`: `niri` when `NIRI_SOCKET` is set (niri sets it for what it starts), else `kde` when `XDG_CURRENT_DESKTOP` names KDE. `NIRI_SOCKET` goes first because niri started from inside Plasma keeps Plasma's `XDG_CURRENT_DESKTOP`. `ISLAND_COMPOSITOR=kde|niri|other` overrides the guess.

## niri's IPC

`services/NiriService.qml` holds niri's state, read from its event stream on `$NIRI_SOCKET`: workspaces, windows, the focused window and output, the overview, keyboard layouts and config loads. The state is built by `services/niriState.js`, which has no Qt in it, so `tests/tst_niriState.qml` replays recorded streams from `tests/data/niri/` into it. When the stream closes (niri restarted) the service reconnects, more slowly if it keeps dropping, and builds the state again.

`NiriService.action(name, fields, onReply)` sends one of niri's actions, as its IPC names them (`FocusWindow`, `{ "id": 3 }`), each on a short-lived connection of its own, since the event stream takes no requests.

## What changes outside KDE

- **Windows:** `kwin_window_tracker.py` is not started (it loads a KWin script). Under niri `WindowService.windowList` comes from `NiriService` (`syncNiri`, through `niriState.trackedWindows`), so the dock's windows are tracked as under KWin and closing, focusing and moving them goes through niri's actions. niri has no minimize or keep above: `WindowService.canMinimize` and `canKeepAbove` are false and those menu entries are hidden. Maximize is niri's `MaximizeWindowToEdges`. On other desktops the active window comes from `ToplevelManager.activeToplevel` (`syncToplevel`).
- **Workspaces:** the virtual desktops pill shows the workspaces of its own output (`niriState.desktopsOn`), without niri's trailing empty one unless it is active, and an urgent one in red. The scroll wheel steps through them, and a click focuses one. niri makes and removes workspaces itself, so `canEditDesktops` is false and New and Remove are hidden. Menus say "Workspace" (`WindowService.desktopNoun`).
- **Dock:** by default under niri the dock hides while a window is under it and reserves no space, since niri's columns fill the screen. Tiled windows count as covering it (`spansHeight` in `dock/dockOverlap.js`, tested by `tests/tst_dockOverlap.qml`); floating ones by their position. It shows while niri's overview is open. Launchpad (KRunner) is KDE's and does nothing elsewhere.
- **Main screen:** without `kscreen-doctor` the main screen is the one niri focused when the shell started, kept while it is connected (`ScreenService.pickNiriPrimary`).
- **Settings buttons:** Bluetooth and network settings open `blueman-manager` or `overskride`, and `nm-connection-editor`, when one is installed, and are hidden otherwise. Power has none outside KDE. `WindowService.openSettings` opens niri-settings under niri. `WindowService.openNiriSettings(page)` opens it at a page (`binds`, `appearance`, `layer-rules`, `files`), when the installed niri-settings knows `--page`.
- **Night Light** is KWin's, so `NightLightService.available` is false and the page says so.
- **Dial:** the Settings tiles that open KDE's settings modules (`KDE_SETTINGS_TILES` in `dialLogic.js`) are dimmed without `systemsettings` or `kcmshell6`. Terminal apps open through `WindowService.launchInTerminal`: Konsole under KDE, else `xdg-terminal-exec`, `$TERMINAL` or the first common terminal found.

## Settings

The first start under niri, with no `settings.json` yet, runs on niri's defaults: the full-width bar set to Always with auto-hide off, the status icons in the top-right corner (`dialStatusIcons` off), the virtual desktops pill on, and the dock hiding while a window is under it. The values are `niriDefaults` in `services/settingChoices.js`, and `firstStartSettings` picks them (both tested by `tests/tst_settingChoices.qml`). They are saved with the first save like any other setting, so a later start, which finds `settings.json`, never applies them again over a change. `SettingsService.firstStartDefaults` names the keys for the welcome guide during that first run.

The Top bar page of the settings window starts with a Use niri defaults button (`SettingsService.applyNiriDefaults`) that sets them again.

The welcome guide has a niri step (`onboarding/OnboardingNiri.qml`, only under niri): the layout it started with, the notification and waybar checks below with their fixes, a button that binds Mod+Space to the launcher through the Shortcuts writer (refused, with the reason, when another bind has the key), and a link to niri-settings.

## Icons

Outside Plasma Qt has no platform theme to name the icon theme, and most icons do not load. `run.sh` sets `QS_ICON_THEME` to KDE's theme from `kdeglobals`, else GNOME's from `gsettings`, unless it is set already or the session is KDE's. Start the shell through `run.sh` (niri runs `~/.config/autostart` entries).

## Notifications

The island is a notification server only if it gets `org.freedesktop.Notifications` first. niri's default setup starts `mako`, which takes it (the log says "Could not register notification server"). Stop and mask it (`systemctl --user mask --now mako.service`) and restart the shell. The default config also starts `waybar`, a top bar of its own: comment out `spawn-at-startup "waybar"` in `~/.config/niri/config.kdl` and stop it (`pkill -x waybar`).

`NotificationService.checkConflicts` looks for both: the process that owns the name (`GetConnectionUnixProcessID`, then `/proc/<pid>/comm`; the shell itself is `$PPID` of the check) and a running `waybar`. It runs 5 seconds after start, and again when the Health section of the About page or the guide's niri step opens; both name what they found and show the fix to copy (`services/desktopConflicts.js`, tested by `tests/tst_desktopConflicts.qml`). It runs on every desktop.

When niri fails to load its config (`ConfigLoaded` with `failed`), the island shows a notification from niri, with a button to niri-settings' Config files page when it is installed. A good load clears it. niri's own red banner can then be turned off in `config.kdl`:

```kdl
config-notification {
    disable-failed
}
```

## Shortcuts

KDE's global shortcuts are not there, so under niri the Shortcuts tab of the settings window binds the shell's IPC commands in the `binds` block of niri's `config.kdl` (`$NIRI_CONFIG`, else `~/.config/niri/config.kdl`) instead. Each row is one command with all its keys: click a key to change it, its cross to remove it, or + to add another. niri's own actions (windows, layout, workspaces...) are left to niri-settings' Key bindings page, which the last row opens (or links to, when it is not installed).

- `scripts/niri_binds.py` reads and writes the file; the parsing and editing are in `scripts/niri_binds_core.py` (tested by `tests/test_niri_binds_core.py`). Edits change only the bind they touch, so comments, spacing and properties such as `repeat=false` stay. A new key for a bound action goes on the line after its other keys, otherwise at the end of the block.
- Each change is written beside the config, checked with `niri validate` and only then moved over it, so niri never loads a broken file; its reason is shown when it refuses one. The previous file is kept as `config.kdl.bak-shortcuts`. niri reloads the config by itself.
- A key another action has is refused with Use anyway, which removes it from that action first.
- The shell's IPC commands are listed even while unbound; other binds are not listed, but are still read so a key one of them has is found. A new shell bind runs `quickshell ipc -p <this checkout> call ...` with `repeat=false`; existing binds count as shell ones only when they reach this checkout.
- While a row waits for keys the window holds a `ShortcutInhibitor`, so niri does not act on a combination it already has. Key presses become niri key names in `services/niriKeys.js` (tested by `tests/tst_niriKeys.qml`). Super is written `Mod`. niri matches the unshifted key, so with Shift the number row is read from its scan code and other symbols are mapped back as on a US layout: on other layouts check what a Shift+symbol combination recorded.
- Binds in files the config `include`s are not shown.

## Launcher shortcut

Bind a key on the Shortcuts tab (Shell, Toggle the dial or Toggle app launcher), or by hand in `config.kdl`:

```kdl
binds {
    Mod+Space { spawn "quickshell" "ipc" "-p" "/path/to/quickshell" "call" "launcher" "toggle"; }
}
```

With Launcher Style set to Dial this opens the dial; `call dial toggle` opens it whatever the style.

niri binds key combinations only: it cannot tell a tap of Super from a hold, so the dial cannot open on Super alone as KDE's launcher does. A tap would need a key remapper such as keyd, which runs system-wide.

## Trying it from Plasma

Run `niri` in a Plasma terminal: it opens as a window. Open a terminal inside it (Mod+T by default) and start the shell there with `./run.sh`, so it gets niri's `WAYLAND_DISPLAY` and `NIRI_SOCKET`. The session bus is still Plasma's.

## Blur

niri 26.04 blurs a layer surface that asks for it, as the glass style does, unless the config turns blur off (`blur { off }`) or a `layer-rule` sets `background-effect { blur false }` for it. By default the blur shows only the wallpaper (xray). `scripts/niri_blur.py` reads the config and the files it includes (the parsing is `scripts/niri_blur_core.py`, tested by `tests/test_niri_blur_core.py`), and `NiriService.blur` holds what it found, read again when `config.kdl` changes. `Theme.blurAvailable` is false when the config keeps the island from being blurred, and the Style row of the Appearance page then says why, with the layer-rule that blurs the windows behind too and a button to niri-settings. See `docs/GLASS.md`.

## Shell tests

`tests/fake_niri.py` stands in for niri's socket: it serves the recordings in `tests/data/niri/` as the event stream and logs the actions it is sent. `tests/run_fixtures.sh` starts it for a fixture with a `niri` file in its folder; see `docs/TESTING.md`.
