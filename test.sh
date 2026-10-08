#!/usr/bin/env bash
# Run the QML unit tests in tests/ headless with qmltestrunner.
# These cover pure logic only; the UI is still checked by hand in the running shell.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

# qmltestrunner is often not on PATH; Fedora and Arch keep it in the Qt bin directory
RUNNER="$(command -v qmltestrunner qmltestrunner6 /usr/lib64/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qmltestrunner 2>/dev/null | head -n 1)"
if [ -z "$RUNNER" ]; then
    echo "qmltestrunner not found (install the Qt 6 declarative tools)" >&2
    exit 1
fi

QT_QPA_PLATFORM=offscreen exec "$RUNNER" -input tests "$@"
