#!/usr/bin/env bash
# QuickShell Island Runner Script

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Quickshell does not stop the Python helpers it started; stale ones (e.g. a second
# kwin_window_tracker) keep the new shell from getting window state
# island_run.py is started by the user to wrap a command, not by the shell, so it is left running
stop_helpers() {
    pgrep -af "$DIR/scripts/.*\.py" 2>/dev/null | grep -v "island_run\.py" | cut -d' ' -f1 | xargs -r kill 2>/dev/null || true
}

# The user's config files live apart from the shell's (SettingsService.configDir):
# $ISLAND_CONFIG_DIR, else ~/.config/quickshell-island. Set ISLAND_CONFIG_DIR to give a
# checkout config of its own, e.g. ISLAND_CONFIG_DIR="$PWD" for the old place.
export ISLAND_CONFIG_DIR="${ISLAND_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell-island}"
CONFIG_FILES=(settings.json dock_pinned.json dial_pinned.json launcher_usage.json)

# Older versions kept the config files in the shell folder: move them over once. A file
# already in the config folder wins, and the old one stays where it was.
move_config() {
    local name
    mkdir -p "$ISLAND_CONFIG_DIR"
    [ "$(realpath "$ISLAND_CONFIG_DIR")" = "$DIR" ] && return
    for name in "${CONFIG_FILES[@]}"; do
        if [ -e "$DIR/$name" ] && [ ! -e "$ISLAND_CONFIG_DIR/$name" ]; then
            mv "$DIR/$name" "$ISLAND_CONFIG_DIR/$name" && echo "Moved $name to $ISLAND_CONFIG_DIR"
        elif [ -e "$DIR/$name" ]; then
            echo "Using $ISLAND_CONFIG_DIR/$name; an older $name is still in $DIR" >&2
        fi
    done
}

# The supervisor that ./run.sh -d starts (supervise below) writes its PID here
SUPERVISOR_PID="${XDG_RUNTIME_DIR:-/tmp}/quickshell-island-$(printf '%s' "$DIR" | cksum | cut -d' ' -f1).pid"

# Stops a running supervisor first, so stopping its shell is not taken for a crash
stop_supervisor() {
    local pid
    pid="$(cat "$SUPERVISOR_PID" 2>/dev/null)"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$SUPERVISOR_PID"
}

# Stops the running shell, its supervisor and its helpers, before starting one
stop_shell() {
    stop_supervisor
    quickshell kill -p "$DIR" 2>/dev/null || true
    stop_helpers
}

# True while the compositor that started this session is still there
compositor_alive() {
    local socket="$WAYLAND_DISPLAY"
    [ -n "$socket" ] || return 1
    case "$socket" in /*) ;; *) socket="${XDG_RUNTIME_DIR:-/tmp}/$socket" ;; esac
    [ -S "$socket" ]
}

# Runs the shell as the login session's: output to the journal (journalctl --user
# -t quickshell-island) and no hot reload, so an update being written is not loaded
# half done. Restarts it when it dies on its own (a crash, or Qt's exit on a lost
# Wayland connection, which no signal reports) while the compositor is still up,
# waiting longer after each quick failure and giving up after five in a row. A shell
# stopped with `quickshell kill` (exit 0) or SIGTERM/SIGINT stays stopped.
supervise() {
    echo $$ >"$SUPERVISOR_PID"
    local child=""
    trap '[ -n "$child" ] && kill "$child" 2>/dev/null; rm -f "$SUPERVISOR_PID"; exit 0' TERM INT
    export QS_DISABLE_FILE_WATCHER=1 QS_NO_RELOAD_POPUP=1

    local failures=0 delay started code
    while true; do
        started=$SECONDS
        if command -v systemd-cat >/dev/null 2>&1; then
            systemd-cat -t quickshell-island quickshell -p "$DIR" --no-color &
        else
            quickshell -p "$DIR" --no-color >/dev/null 2>&1 &
        fi
        child=$!
        # wait returns early when a trap fires, so -k stops this loop at once
        wait "$child"
        code=$?
        child=""
        case "$code" in 0|130|143) break ;; esac
        compositor_alive || break
        # A shell that ran for a minute counts as healthy again
        [ $((SECONDS - started)) -ge 60 ] && failures=0
        failures=$((failures + 1))
        if [ "$failures" -gt 5 ]; then
            echo "Quickshell Island exited $failures times in a row (last exit $code); not restarting" \
                | systemd-cat -t quickshell-island -p err 2>/dev/null
            break
        fi
        delay=$((1 << (failures - 1)))
        echo "Quickshell Island exited with $code; restarting in ${delay}s" \
            | systemd-cat -t quickshell-island -p warning 2>/dev/null
        stop_helpers
        sleep "$delay" &
        wait $!
    done
    rm -f "$SUPERVISOR_PID"
}

# Quickshell gives editors its import paths only when .qmlls.ini exists: it then replaces the
# file with a link to the config it writes under $XDG_RUNTIME_DIR. Without it, the editor's
# qmlls reports every QtQuick and Quickshell type as not found
enable_qml_tooling() {
    [ -e "$DIR/.qmlls.ini" ] || [ -L "$DIR/.qmlls.ini" ] || : > "$DIR/.qmlls.ini"
}

# Outside Plasma Qt has no platform theme to name the icon theme, so most icons would not
# load. Take KDE's choice from kdeglobals, else GNOME's, unless QS_ICON_THEME is set.
set_icon_theme() {
    [ -n "$QS_ICON_THEME" ] && return
    [ "$KDE_FULL_SESSION" = "true" ] && return
    case ":$XDG_CURRENT_DESKTOP:" in *:KDE:*) return ;; esac
    local theme=""
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals" ]; then
        theme="$(sed -n '/^\[Icons\]/,/^\[/s/^Theme=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals" | head -n 1)"
    fi
    if [ -z "$theme" ] && command -v gsettings >/dev/null 2>&1; then
        theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
    fi
    [ -n "$theme" ] && export QS_ICON_THEME="$theme"
}

case "$1" in
    kill|-k|--kill)
        echo "Stopping Quickshell Island..."
        stop_supervisor
        quickshell kill -p "$DIR" 2>/dev/null || pkill -f "quickshell.*$DIR"
        quickshell kill -p "$DIR" 2>/dev/null || killall -q quickshell 2>/dev/null || true
        stop_helpers
        ;;
    launcher|-l|--launcher)
        quickshell ipc -p "$DIR" call launcher toggle
        ;;
    windows|-w|--windows)
        quickshell ipc -p "$DIR" call launcher windows
        ;;
    clipboard|-v|--clipboard)
        quickshell ipc -p "$DIR" call clipboard toggle
        ;;
    toggle|-t|--toggle)
        echo "Toggling Island..."
        quickshell ipc -p "$DIR" call island toggle
        ;;
    expand|-e|--expand)
        quickshell ipc -p "$DIR" call island expand
        ;;
    collapse|-c|--collapse)
        quickshell ipc -p "$DIR" call island collapse
        ;;
    ipc|-i|--ipc)
        shift
        quickshell ipc -p "$DIR" call "$@"
        ;;
    check|--check)
        # The check is a Python script, so a missing Python has to be reported here
        if ! command -v python3 >/dev/null 2>&1; then
            echo "python3 was not found. Install Python 3, then run this check again." >&2
            exit 1
        fi
        shift
        exec python3 "$DIR/scripts/check_deps.py" "$@"
        ;;
    run|--run)
        if ! command -v python3 >/dev/null 2>&1; then
            echo "python3 was not found. Install Python 3 to use this." >&2
            exit 1
        fi
        shift
        exec python3 "$DIR/scripts/island_run.py" "$@"
        ;;
    sandbox|--sandbox)
        # A private bus with its own activities bridge, for trying the D-Bus helpers
        if ! command -v dbus-run-session >/dev/null 2>&1; then
            echo "dbus-run-session was not found. Install dbus (dbus-daemon or dbus-broker) to use this." >&2
            exit 1
        fi
        shift
        ISLAND_SANDBOX_BUS=1 exec dbus-run-session --config-file="$DIR/scripts/sandbox_bus.conf" -- bash "$DIR/scripts/sandbox.sh" "$@"
        ;;
    export|--export)
        shift
        exec python3 "$DIR/scripts/settings_backup.py" export "$@"
        ;;
    import|--import)
        shift
        python3 "$DIR/scripts/settings_backup.py" import "$@" || exit 1
        # A running shell still holds the old config and would write it back, so make it reload
        quickshell ipc -p "$DIR" call config reload >/dev/null 2>&1 || true
        ;;
    daemon|-d|--daemon)
        echo "Starting Quickshell Island in background..."
        stop_shell
        move_config
        enable_qml_tooling
        set_icon_theme
        # Detached from this terminal and from a shell that ran this (Update's restart)
        setsid -f "$DIR/run.sh" --supervise </dev/null >/dev/null 2>&1
        ;;
    --supervise)
        supervise
        ;;
    *)
        echo "Starting Quickshell Island..."
        stop_shell
        move_config
        enable_qml_tooling
        set_icon_theme
        exec quickshell -p "$DIR"
        ;;
esac
