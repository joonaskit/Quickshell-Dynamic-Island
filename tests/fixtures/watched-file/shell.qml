import QtQuick
import Quickshell
import Quickshell.Io
import "fixture"

// WatchedFile follows a file through every way it changes: created, written in place,
// replaced by a rename as editors save, written again after that, and removed.
ShellRoot {
    id: root

    readonly property string file: steps.work + "/watched.txt"

    // Runs a shell command in the fixture's work directory
    function sh(cmd) {
        shell.command = ["sh", "-c", "cd \"$FIXTURE_WORK\" && " + cmd];
        shell.running = true;
    }

    // The command has finished and the file reads `text`
    function reads(text) {
        return !shell.running && watched.text === text;
    }

    WatchedFile {
        id: watched
        path: root.file
    }

    Process {
        id: shell
    }

    Steps {
        id: steps
        steps: [
            { name: "missing", until: () => steps.expect("text", watched.text, "") },
            { name: "created", run: () => root.sh("printf one > watched.txt"), until: () => root.reads("one") },
            { name: "written in place", run: () => root.sh("printf two > watched.txt"), until: () => root.reads("two") },
            { name: "appended", run: () => root.sh("printf ' more' >> watched.txt"), until: () => root.reads("two more") },
            { name: "replaced by rename", run: () => root.sh("printf three > new.tmp && mv new.tmp watched.txt"), until: () => root.reads("three") },
            { name: "written after the rename", run: () => root.sh("printf four > watched.txt"), until: () => root.reads("four") },
            { name: "replaced twice quickly", run: () => root.sh("printf five > a.tmp && mv a.tmp watched.txt && printf six > b.tmp && mv b.tmp watched.txt"), until: () => root.reads("six") },
            { name: "removed", run: () => root.sh("rm watched.txt"), until: () => root.reads("") },
            { name: "created again", run: () => root.sh("printf seven > watched.txt"), until: () => root.reads("seven") }
        ]
    }
}
