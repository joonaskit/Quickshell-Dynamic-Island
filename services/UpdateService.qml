pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Checks for updates and applies one through scripts/update_check.py, which does
// all the git work. Only on request for now. The channel is SettingsService.updateChannel.
// See docs/UPDATES.md.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/update_check.py"

    // The last result from the script, or null before the first check
    property var result: null
    readonly property bool busy: proc.running
    property string action: ""
    // True once an update was applied, until the shell is restarted
    property bool restartNeeded: false

    // One line for the settings page
    readonly property string summary: {
        if (root.busy) return root.action === "update" ? "Updating…" : "Checking…";
        let r = root.result;
        if (!r) return "Not checked yet";
        switch (r.state) {
        case "up-to-date": return "Up to date (" + r.current + ")";
        case "available": return (r.channel === "stable" ? r.target + " is available" : r.behind + (r.behind === 1 ? " new commit" : " new commits")) + " (you have " + r.current + ")";
        case "updated": return "Updated to " + r.current + ". Restart the shell to use it";
        case "local-changes": return "An update is available, but the shell's files have local changes, so it is not applied";
        case "diverged": return "This install has commits that are not on main, so it cannot be updated";
        case "other-branch": return "This checkout is not on main, so updates are left to you";
        case "not-git": return "This install is not a git checkout, so it cannot update itself. Run install.sh again";
        case "no-git": return "Git is not installed";
        case "no-target": return r.channel === "stable" ? "No release found" : "No main branch found on the remote";
        case "offline": return "Could not reach the remote: " + r.error;
        case "failed": return "The update failed: " + r.error;
        }
        return "The check did not finish";
    }
    readonly property bool isError: !!root.result && !root.busy && (root.result.state === "offline" || root.result.state === "failed" || root.result.state === "diverged" || root.result.state === "no-git")
    readonly property bool canUpdate: !root.busy && !!root.result && root.result.canUpdate

    function run(action) {
        if (proc.running) return;
        root.action = action;
        proc.command = ["python3", root.script, action, "--channel", SettingsService.updateChannel];
        proc.running = true;
    }

    function check() { root.run("check"); }
    function update() { if (root.canUpdate) root.run("update"); }

    // The same start as the autostart entry. setsid keeps it alive while run.sh stops this shell
    function restart() {
        Quickshell.execDetached(["setsid", "-f", Quickshell.shellDir + "/run.sh", "-d"]);
    }

    // A result for one channel says nothing about the other
    Connections {
        target: SettingsService
        function onUpdateChannelChanged() {
            if (root.result && root.result.state !== "updated") root.result = null;
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = null;
                try {
                    parsed = JSON.parse(text.trim());
                } catch (e) {}
                root.result = parsed && parsed.state ? parsed : { "state": "", "canUpdate": false };
                if (root.result.state === "updated") {
                    root.restartNeeded = true;
                    // An update can need a new tool
                    DepsService.runCheck();
                }
            }
        }
    }
}
