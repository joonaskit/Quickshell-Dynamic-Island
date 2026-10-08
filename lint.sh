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
    git ls-files -z '*.qml' | xargs -0 "$QMLLINT" || status=1
else
    echo "qmllint not found (install the Qt 6 declarative tools)" >&2
    status=1
fi

if command -v ruff >/dev/null 2>&1; then
    RUFF=(ruff)
elif command -v uvx >/dev/null 2>&1; then
    RUFF=(uvx ruff)
fi
if [ -n "${RUFF[*]}" ]; then
    echo "== ruff"
    "${RUFF[@]}" check scripts/ || status=1
else
    echo "ruff not found (install ruff or uv)" >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "Lint passed"
exit "$status"
