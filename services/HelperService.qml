pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Health of the long-running helper scripts the shell starts. Each service
// registers its Process with watch(); this counts starts and exits for the
// Health section of the About page. scripts/helper_health.py finds leftover
// helpers from an earlier run, and the diagnostic report is built here.
Singleton {
    id: root

    // One entry per helper: { id, name, running, starts, crashes, lastExit, off, note }.
    // off is a helper the user turned off, note a word on how a running one is doing
    property var entries: []
    // Helpers running that this shell did not start: [{ pid, script }]
    property var stale: []
    property bool scanned: false
    property string notice: ""

    readonly property int problemCount: {
        let n = root.stale.length;
        for (let e of root.entries) if (!e.off && (!e.running || e.crashes > 0)) n++;
        return n;
    }

    property var procs: ({})
    // Ids being stopped on purpose, so that the exit is not counted as a crash
    property var stopping: ({})
    property var versions: ({})

    // Registers a helper's Process. Called by the service that owns it.
    function watch(id, name, proc) {
        root.procs[id] = proc;
        root.update(id, { name: name, running: proc.running, starts: proc.running ? 1 : 0, crashes: 0, lastExit: null });
        proc.runningChanged.connect(() => root.onRunningChanged(id));
        proc.exited.connect((code, status) => root.onExited(id, code, status));
    }

    // Sets off or note for a helper that can be turned off or that reports how it is doing
    function setStatus(id, fields) {
        if (root.find(id)) root.update(id, fields);
    }

    function find(id) {
        return root.entries.find(e => e.id === id);
    }

    function update(id, fields) {
        let list = root.entries.filter(e => e.id !== id);
        let old = root.find(id) || { id: id };
        list.push(Object.assign({}, old, fields));
        root.entries = list.sort((a, b) => a.name.localeCompare(b.name));
    }

    function onRunningChanged(id) {
        let entry = root.find(id);
        let running = root.procs[id].running;
        if (!entry || entry.running === running) return;
        root.update(id, running ? { running: true, starts: entry.starts + 1 } : { running: false });
    }

    function onExited(id, code, status) {
        let entry = root.find(id);
        if (!entry) return;
        let expected = !!root.stopping[id] || !!entry.off;
        root.update(id, {
            running: false,
            crashes: expected ? entry.crashes : entry.crashes + 1,
            lastExit: expected ? "stopped" : (status === 0 ? "exit code " + code : "crashed")
        });
    }

    function statusText(e) {
        if (e.off) return "Off";
        if (!e.running) return e.lastExit ? "Stopped (" + e.lastExit + ")" : "Not running";
        let restarts = e.starts - 1;
        if (restarts <= 0) return e.note ? e.note : "Running";
        return "Running, restarted " + restarts + (restarts === 1 ? " time" : " times");
    }

    // Stops every helper and starts it again. The services' own restart timers
    // do the same, so a helper that is already back is left alone.
    function restartAll() {
        for (let id in root.procs) {
            if (root.find(id).off) continue;
            root.stopping[id] = true;
            root.procs[id].running = false;
        }
        restartTimer.restart();
        root.notice = "Restarting helpers…";
    }

    Timer {
        id: restartTimer
        interval: 1500
        onTriggered: {
            for (let id in root.procs) {
                root.stopping[id] = false;
                if (root.find(id).off) continue;
                if (!root.procs[id].running) root.procs[id].running = true;
            }
            root.notice = "Helpers restarted";
            root.scan();
        }
    }

    function ownedPids() {
        let pids = [];
        for (let id in root.procs) {
            let pid = root.procs[id].processId;
            if (pid) pids.push(pid);
        }
        return pids.join(",");
    }

    function scan() {
        if (!scanProc.running) {
            scanProc.killStale = false;
            scanProc.command = root.scanCommand(false);
            scanProc.running = true;
        }
    }

    function stopStale() {
        if (!scanProc.running) {
            scanProc.killStale = true;
            scanProc.command = root.scanCommand(true);
            scanProc.running = true;
        }
    }

    function scanCommand(kill) {
        let cmd = ["python3", Quickshell.shellDir + "/scripts/helper_health.py", "scan", Quickshell.shellDir, "--owned", root.ownedPids()];
        return kill ? cmd.concat(["--kill"]) : cmd;
    }

    Process {
        id: scanProc
        property bool killStale: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text.trim());
                    root.stale = res.helpers.filter(h => h.stale);
                    root.scanned = true;
                    if (scanProc.killStale) {
                        root.notice = res.killed.length > 0 ? "Stopped " + res.killed.length + " stale " + (res.killed.length === 1 ? "helper" : "helpers") : "Nothing to stop";
                        root.stale = [];
                    }
                } catch (e) {
                    console.warn("[HelperService] Error parsing scan output:", e);
                }
            }
        }
    }

    // The home directory is shown as ~ and no settings or tokens are included
    function redact(text) {
        let home = Quickshell.env("HOME") || "";
        return home.length > 1 ? text.split(home).join("~") : text;
    }

    function report() {
        let lines = ["Quickshell Island diagnostic report", ""];
        let v = root.versions;
        lines.push("Quickshell: " + (v.quickshell || "unknown"));
        lines.push("Python: " + (v.python || "unknown"));
        lines.push("Shell commit: " + (v.commit || "unknown"));
        lines.push("Kernel: " + (v.kernel || "unknown"));
        lines.push("Session: " + (Quickshell.env("XDG_SESSION_TYPE") || "unknown") + ", " + (Quickshell.env("XDG_CURRENT_DESKTOP") || "unknown"));
        lines.push("Shell directory: " + Quickshell.shellDir);
        lines.push("");
        lines.push("Dependencies:");
        if (DepsService.report) {
            for (let d of DepsService.report.dependencies) {
                lines.push("  " + d.name + " (" + d.severity + "): " + d.status);
            }
        } else {
            lines.push("  " + (DepsService.checkFailed ? "check failed" : "not checked yet"));
        }
        lines.push("");
        lines.push("Helpers:");
        for (let e of root.entries) lines.push("  " + e.name + ": " + root.statusText(e));
        lines.push("Stale helper processes: " + (root.stale.length === 0 ? "none" : root.stale.map(s => s.script + " (pid " + s.pid + ")").join(", ")));
        return root.redact(lines.join("\n"));
    }

    function copyReport() {
        copyProc.command = ["wl-copy", "--", root.report()];
        copyProc.running = true;
        root.notice = "Report copied";
    }

    Process {
        id: copyProc
    }

    Process {
        id: versionsProc
        command: ["python3", Quickshell.shellDir + "/scripts/helper_health.py", "versions", Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.versions = JSON.parse(text.trim()); } catch (e) {}
            }
        }
    }

    Component.onCompleted: versionsProc.running = true
}
