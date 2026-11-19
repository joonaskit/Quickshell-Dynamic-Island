#!/usr/bin/env bash
# Run the shell tests in tests/fixtures/: each <name>/shell.qml is a small ShellRoot that
# uses the real shell files, checks one behaviour and prints "RESULT pass" or
# "RESULT fail <reason>". They run in a headless KWin on a private D-Bus, with a clean
# environment and a temporary home, so they never touch the desktop you are using.
# See docs/TESTING.md.
#
#   tests/run_fixtures.sh            run every fixture
#   tests/run_fixtures.sh NAME...    run only these
#   tests/run_fixtures.sh --layout DIR NAME
#                                    only lay fixture NAME out in DIR (lint.sh lints it there)
#
# Skipped (exit 0) when quickshell, kwin_wayland or dbus-run-session is missing.

TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$TESTS")"

# The real qmldir and folders, so the fixture's shell.qml sees the shell's types as
# shell.qml does, with the fixture's files and Steps (as "fixture") beside them.
# settings.json and the other config files stay behind: SettingsService reads and
# writes its own, beside the fixture.
layout() {
    local dir="$1" name="$2" d
    mkdir -p "$dir"
    ln -s "$ROOT/qmldir" "$dir/qmldir"
    for d in "$ROOT"/*/; do
        d="${d%/}"
        case "$(basename "$d")" in tests|docs|desing) continue ;; esac
        ln -s "$d" "$dir/$(basename "$d")"
    done
    cp "$TESTS/fixtures/$name/"*.qml "$dir/"
    ln -s "$TESTS/fixtures/lib" "$dir/fixture"
}

if [ "$1" = "--layout" ]; then
    layout "$2" "$3"
    exit
fi

# Inside the headless session: run each fixture and write the failures to $FIXTURE_STATUS
if [ -n "$FIXTURE_NAMES" ]; then
    failed=0
    for name in $FIXTURE_NAMES; do
        dir="$FIXTURE_TMP/run/$name"
        mkdir -p "$FIXTURE_TMP/work/$name"
        layout "$dir" "$name"
        log="$FIXTURE_TMP/$name.log"
        FIXTURE_WORK="$FIXTURE_TMP/work/$name" timeout -k 2 20 quickshell -p "$dir" --no-color >"$log" 2>&1
        code=$?
        result="$(grep -o 'RESULT .*' "$log" | tail -n 1)"
        # A script error in the shell's own files fails the fixture even when its checks
        # pass: it is the warning a hand check is most likely to miss
        errors="$(grep -E 'ReferenceError|TypeError' "$log")"
        if [ "$result" = "RESULT pass" ] && [ "$code" -eq 0 ] && [ -z "$errors" ]; then
            echo "PASS $name"
        else
            [ "$result" = "RESULT pass" ] && [ -n "$errors" ] && result="script errors"
            echo "FAIL $name: ${result:-no result (exit $code)}"
            sed 's/^/    /' "$log"
            failed=1
        fi
    done
    echo "$failed" >"$FIXTURE_STATUS"
    exit 0
fi

for tool in quickshell kwin_wayland dbus-run-session; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Shell tests skipped: $tool not found"
        exit 0
    fi
done

if [ $# -gt 0 ]; then
    names=("$@")
else
    names=()
    for f in "$TESTS"/fixtures/*/shell.qml; do
        names+=("$(basename "$(dirname "$f")")")
    done
fi
[ ${#names[@]} -eq 0 ] && exit 0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p -m 700 "$tmp/runtime"
mkdir -p "$tmp/home"

# A bus with no service files, so nothing on it is started on demand (portals, a
# secrets daemon), and nothing outlives the run
cat >"$tmp/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:dir=$tmp/runtime</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF

echo "== shell tests"
# A clean environment: nothing from the running desktop (its Wayland and X displays,
# niri's socket, the session bus) reaches the fixtures
status_file="$tmp/status"
env -i \
    PATH="$PATH" LANG="${LANG:-C.UTF-8}" \
    HOME="$tmp/home" \
    XDG_RUNTIME_DIR="$tmp/runtime" \
    XDG_CONFIG_HOME="$tmp/home/.config" \
    XDG_CACHE_HOME="$tmp/home/.cache" \
    XDG_DATA_HOME="$tmp/home/.local/share" \
    XDG_STATE_HOME="$tmp/home/.local/state" \
    FIXTURE_TMP="$tmp" FIXTURE_STATUS="$status_file" FIXTURE_NAMES="${names[*]}" \
    timeout -k 5 120 setsid --wait \
    dbus-run-session --config-file="$tmp/bus.conf" -- \
    kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --socket island-test \
    --exit-with-session "$TESTS/run_fixtures.sh" 2>"$tmp/kwin.log"

if [ ! -f "$status_file" ]; then
    echo "The headless KWin did not run the shell tests:" >&2
    grep -v -e '^$' -e 'radv is not a conformant' "$tmp/kwin.log" | sed 's/^/    /' >&2
    exit 1
fi
[ "$(cat "$status_file")" = "0" ]
