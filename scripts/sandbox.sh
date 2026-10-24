#!/usr/bin/env bash
# Runs a command on a private D-Bus bus, next to its own activities_bridge.py,
# so D-Bus helpers can be tried without touching the live desktop session.
# Started by ./run.sh --sandbox, which puts it on the private bus.
#
# The bridge's stdout (one JSON line per change, see activities_bridge.py) goes
# to $ISLAND_SANDBOX_LOG, or to a new file under /tmp, and the command gets its
# path in ISLAND_SANDBOX_LOG. With no command, an interactive shell is started.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] || [ "$ISLAND_SANDBOX_BUS" != "1" ]; then
    echo "sandbox.sh runs on the private bus: start it with ./run.sh --sandbox" >&2
    exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/island-sandbox.XXXXXX")" || exit 1
export ISLAND_SANDBOX_LOG="${ISLAND_SANDBOX_LOG:-$work/activities.jsonl}"
: > "$ISLAND_SANDBOX_LOG" || exit 1

# The bridge exits when its stdin closes, as it does when the shell goes, so it
# reads from a pipe that is held open until the sandbox ends
mkfifo "$work/stdin"
exec 3<>"$work/stdin"
python3 "$DIR/scripts/activities_bridge.py" <&3 >"$ISLAND_SANDBOX_LOG" &
bridge=$!

cleanup() {
    kill "$bridge" 2>/dev/null
    wait "$bridge" 2>/dev/null
    exec 3>&-
    rm -rf "$work"
}
trap cleanup EXIT

# The bridge prints its first (empty) list once it owns its name
for _ in $(seq 50); do
    [ -s "$ISLAND_SANDBOX_LOG" ] && break
    if ! kill -0 "$bridge" 2>/dev/null; then
        echo "activities_bridge.py exited before it was ready" >&2
        exit 1
    fi
    sleep 0.1
done
if [ ! -s "$ISLAND_SANDBOX_LOG" ]; then
    echo "activities_bridge.py did not start" >&2
    exit 1
fi

echo "Sandbox bus: $DBUS_SESSION_BUS_ADDRESS" >&2
echo "Activities log: $ISLAND_SANDBOX_LOG" >&2

if [ "$#" -eq 0 ]; then
    "${SHELL:-bash}"
else
    "$@"
fi
