#!/usr/bin/env bash
# Run the tests in tests/: the QML unit tests (tst_*.qml) headless with qmltestrunner,
# the Python ones (test_*.py) with unittest, then the shell tests (tests/fixtures/) in
# a headless KWin. See docs/TESTING.md.

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
tests/run_fixtures.sh || status=1
exit "$status"
