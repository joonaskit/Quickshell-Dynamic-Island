#!/usr/bin/env bash
# QuickShell Island Runner Script

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Quickshell does not stop the Python helpers it started; stale ones (e.g. a second
# kwin_window_tracker) keep the new shell from getting window state
# island_run.py is started by the user to wrap a command, not by the shell, so it is left running
stop_helpers() {
    pgrep -af "$DIR/scripts/.*\.py" 2>/dev/null | grep -v "island_run\.py" | cut -d' ' -f1 | xargs -r kill 2>/dev/null || true
}

case "$1" in
    kill|-k|--kill)
        echo "Stopping Quickshell Island..."
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
        quickshell kill -p "$DIR" 2>/dev/null || true
        stop_helpers
        quickshell -p "$DIR" --daemonize
        ;;
    *)
        echo "Starting Quickshell Island..."
        quickshell kill -p "$DIR" 2>/dev/null || true
        stop_helpers
        exec quickshell -p "$DIR"
        ;;
esac
