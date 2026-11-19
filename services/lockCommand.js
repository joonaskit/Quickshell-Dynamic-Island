.pragma library

// The command the Lock button runs (PowerService.lock). KDE's locker listens for logind's
// Lock signal, so `loginctl lock-session` is enough there. Under niri and other desktops
// usually nothing listens, so a locker is run directly. tests/tst_lockCommand.qml runs it.

// Lockers to look for, in order, with the arguments that make each lock and return
const LOCKERS = [
    { "name": "swaylock", "args": ["-f"] },
    { "name": "hyprlock", "args": [] },
    { "name": "gtklock", "args": ["-d"] },
];

function lockerNames() {
    return LOCKERS.map(l => l.name);
}

// custom: $ISLAND_LOCK_COMMAND, a shell command line, used on any desktop when set.
// installed: the locker names found on PATH. Returns the command as a list.
function lockCommand(compositor, custom, installed) {
    if (custom && custom.trim() !== "") return ["sh", "-c", custom];
    if (compositor !== "kde") {
        let found = installed || [];
        for (let i = 0; i < LOCKERS.length; i++) {
            if (found.indexOf(LOCKERS[i].name) >= 0) return [LOCKERS[i].name].concat(LOCKERS[i].args);
        }
    }
    return ["loginctl", "lock-session"];
}

// Names from `command -v` output: one path or name per line
function parseFound(text) {
    return (text || "").split("\n").map(l => l.trim()).filter(l => l !== "").map(l => l.split("/").pop());
}
