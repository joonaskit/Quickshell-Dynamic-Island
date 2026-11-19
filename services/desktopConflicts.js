.pragma library

// Other programs that take the shell's place: a notification daemon that owns
// org.freedesktop.Notifications first (niri's default session starts mako), and a second
// top bar (niri's default config starts waybar). NotificationService runs the check;
// this reads its output and says how to fix each. tests/tst_desktopConflicts.qml runs it.

// The check's output, one "key=value" line each:
// owner=self | owner=<process name> | owner= (no owner), and waybar=1 when it runs.
function parse(text) {
    let result = { "notificationOwner": "", "ownsNotifications": false, "waybar": false };
    let lines = (text || "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        let line = lines[i].trim();
        let eq = line.indexOf("=");
        if (eq < 0) continue;
        let key = line.slice(0, eq);
        let value = line.slice(eq + 1).trim();
        if (key === "owner") {
            result.ownsNotifications = value === "self";
            result.notificationOwner = value === "self" ? "" : value;
        } else if (key === "waybar") {
            result.waybar = value === "1";
        }
    }
    return result;
}

// Daemons that run as a systemd user service of the same name
const DAEMON_SERVICES = {
    "mako": "mako.service",
    "dunst": "dunst.service",
    "swaync": "swaync.service",
    "fnott": "fnott.service",
};

// How to stop a notification daemon: { text, command }; command is "" when unknown
function notificationFix(name) {
    let service = DAEMON_SERVICES[name];
    if (service) {
        return {
            "text": "Stop it and keep it from starting again, then restart the shell",
            "command": "systemctl --user mask --now " + service,
        };
    }
    return {
        "text": "Remove it from your session's autostart, stop it, then restart the shell",
        "command": "",
    };
}

// How to stop waybar; under niri it is usually started by niri's config
function waybarFix(niri) {
    return {
        "text": niri
            ? "Comment out spawn-at-startup \"waybar\" in niri's config.kdl, or if it runs as a service, disable it"
            : "Remove it from your session's autostart, or if it runs as a service, disable it",
        "command": "systemctl --user disable --now waybar.service",
    };
}

// Short lines for logs and the welcome guide
function summary(conflicts) {
    let lines = [];
    if (conflicts && conflicts.notificationOwner)
        lines.push(conflicts.notificationOwner + " shows notifications instead of the island");
    if (conflicts && conflicts.waybar)
        lines.push("waybar is running as a second top bar");
    return lines;
}
