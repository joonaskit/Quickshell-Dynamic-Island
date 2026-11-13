# niri (experimental)

The shell is built for KDE Plasma. Under niri the dial launcher works; the rest of the shell runs but its KDE parts are missing.

## How the compositor is told

`CompositorService.name` is `kde`, `niri` or `other`: `niri` when `NIRI_SOCKET` is set (niri sets it for what it starts), else `kde` when `XDG_CURRENT_DESKTOP` names KDE. `NIRI_SOCKET` goes first because niri started from inside Plasma keeps Plasma's `XDG_CURRENT_DESKTOP`. `ISLAND_COMPOSITOR=kde|niri|other` overrides the guess.

## What changes outside KDE

- **Windows:** `kwin_window_tracker.py` is not started (it loads a KWin script). `WindowService` takes the active window's app, title, maximized, fullscreen and screen from `ToplevelManager.activeToplevel` instead (`syncToplevel`). The window list comes from the toplevels, through `DockService.getMergedWindows` as before. There are no virtual desktops.
- **Night Light** is KWin's, so `NightLightService.available` is false and the page says so.
- **Dial:** the Settings tiles that open KDE's settings modules (`KDE_SETTINGS_TILES` in `dialLogic.js`) are dimmed without `systemsettings` or `kcmshell6`. Terminal apps open through `WindowService.launchInTerminal`: Konsole under KDE, else `xdg-terminal-exec`, `$TERMINAL` or the first common terminal found.

## Icons

Outside Plasma Qt has no platform theme to name the icon theme, and most icons do not load. `run.sh` sets `QS_ICON_THEME` to KDE's theme from `kdeglobals`, else GNOME's from `gsettings`, unless it is set already or the session is KDE's. Start the shell through `run.sh` (niri runs `~/.config/autostart` entries).

## Notifications

The island is a notification server only if it gets `org.freedesktop.Notifications` first. niri's default setup starts `mako`, which takes it (the log says "Could not register notification server"). Stop and mask it (`systemctl --user mask --now mako.service`) and restart the shell. The default config also starts `waybar`, a top bar of its own: comment out `spawn-at-startup "waybar"` in `~/.config/niri/config.kdl` and stop it (`pkill -x waybar`).

## Shortcuts

KDE's global shortcuts are not there, so under niri the Shortcuts tab of the settings window edits the `binds` block of niri's `config.kdl` (`$NIRI_CONFIG`, else `~/.config/niri/config.kdl`) instead. Tabs split the actions into Shell (the shell's IPC commands), Apps (other `spawn` binds), Windows, Layout, Workspaces, Monitors and System; while searching every tab shows. Each row is one action with all its keys: click a key to change it, its cross to remove it, or + to add another.

- `scripts/niri_binds.py` reads and writes the file; the parsing and editing are in `scripts/niri_binds_core.py` (tested by `tests/test_niri_binds_core.py`). Edits change only the bind they touch, so comments, spacing and properties such as `repeat=false` stay. A new key for a bound action goes on the line after its other keys, otherwise at the end of the block.
- Each change is written beside the config, checked with `niri validate` and only then moved over it, so niri never loads a broken file; its reason is shown when it refuses one. The previous file is kept as `config.kdl.bak-shortcuts`. niri reloads the config by itself.
- A key another action has is refused with Use anyway, which removes it from that action first.
- The actions in `CATALOGUE` and the shell's IPC commands are listed even while unbound. A new shell bind runs `quickshell ipc -p <this checkout> call ...` with `repeat=false`; existing binds count as shell ones only when they reach this checkout.
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

## Not done yet

- Workspaces in the virtual desktops pill (`Quickshell.WindowManager` or niri's IPC).
- `deps.json` marks KWin as required, so the dependency check reports it missing.
- Blur: `Theme.blurAvailable` says whether Quickshell has `BackgroundEffect`, not whether the compositor blurs.
