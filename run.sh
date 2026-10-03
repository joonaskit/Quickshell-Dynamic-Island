#!/usr/bin/env bash
# QuickShell Island Runner Script

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    kill|-k|--kill)
        echo "Stopping Quickshell Island..."
        quickshell kill -p "$DIR" 2>/dev/null || killall -q quickshell 2>/dev/null || true
        ;;
    launcher|-l|--launcher)
        quickshell ipc -p "$DIR" call launcher toggle
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
    daemon|-d|--daemon)
        echo "Starting Quickshell Island in background..."
        quickshell kill -p "$DIR" 2>/dev/null || true
        quickshell -p "$DIR" --daemonize
        ;;
    *)
        echo "Starting Quickshell Island..."
        quickshell kill -p "$DIR" 2>/dev/null || true
        exec quickshell -p "$DIR"
        ;;
esac
