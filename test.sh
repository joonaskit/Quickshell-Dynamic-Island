#!/usr/bin/env bash
# Run the unit tests in tests/: the QML ones (tst_*.qml) headless with
# qmltestrunner, then the Python ones (test_*.py) with unittest.
# These cover pure logic only; the UI is still checked by hand in the running shell.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

# qmltestrunner is often not on PATH; Fedora and Arch keep it in the Qt bin directory
RUNNER="$(command -v qmltestrunner qmltestrunner6 /usr/lib64/qt6/bin/qmltestrunner /usr/lib/qt6/bin/qmltestrunner 2>/dev/null | head -n 1)"
if [ -z "$RUNNER" ]; then
    echo "qmltestrunner not found (install the Qt 6 declarative tools)" >&2
    exit 1
fi

status=0
QT_QPA_PLATFORM=offscreen "$RUNNER" -input tests "$@" || status=1
python3 -m unittest discover -s tests -p 'test_*.py' || status=1
exit "$status"
