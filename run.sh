#!/usr/bin/env bash
# QuickShell Island Runner Script

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Quickshell does not stop the Python helpers it started; stale ones (e.g. a second
# kwin_window_tracker) keep the new shell from getting window state
stop_helpers() {
    pkill -f "$DIR/scripts/.*\.py" 2>/dev/null || true
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
