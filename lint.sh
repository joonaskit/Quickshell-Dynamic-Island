#!/usr/bin/env bash
# Lint the QML (qmllint, settings in .qmllint.ini) and the Python helpers (ruff, settings in ruff.toml).
# Exits non-zero if either reports a problem.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

status=0

# qmllint is often not on PATH; Fedora and Arch keep it in the Qt bin directory
QMLLINT="$(command -v qmllint qmllint6 /usr/lib64/qt6/bin/qmllint /usr/lib/qt6/bin/qmllint 2>/dev/null | head -n 1)"
if [ -n "$QMLLINT" ]; then
    echo "== qmllint"
    # Tracked and untracked (not ignored) files, minus any deleted but not yet committed
    git ls-files -z --cached --others --exclude-standard '*.qml' \
        | while IFS= read -r -d '' f; do [ -f "$f" ] && printf '%s\0' "$f"; done \
        | xargs -0 "$QMLLINT" || status=1
else
    echo "qmllint not found (install the Qt 6 declarative tools)" >&2
    status=1
fi

# Every animation length goes through Theme.duration(), so the animation speed setting
# reaches it (docs/ANIMATION_CATALOGUE.md)
echo "== durations"
bare=$(git ls-files -z --cached --others --exclude-standard '*.qml' \
    | xargs -0 grep -nE '\bduration\s*[:=][^/]*[0-9]' 2>/dev/null \
    | grep -v 'Theme\.duration(')
if [ -n "$bare" ]; then
    echo "$bare"
    echo "A duration with a number in it: wrap it in Theme.duration()" >&2
    status=1
fi

if command -v ruff >/dev/null 2>&1; then
    RUFF=(ruff)
elif command -v uvx >/dev/null 2>&1; then
    RUFF=(uvx ruff)
fi
if [ -n "${RUFF[*]}" ]; then
    echo "== ruff"
    "${RUFF[@]}" check scripts/ tests/ examples/ || status=1
else
    echo "ruff not found (install ruff or uv)" >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "Lint passed"
exit "$status"
