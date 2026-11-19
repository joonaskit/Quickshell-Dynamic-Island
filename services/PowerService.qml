pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import "lockCommand.js" as LockCommand

Singleton {
    id: root

    // The lockers on PATH (lockCommand.js picks one outside KDE), found once at start
    property var lockers: []
    // $ISLAND_LOCK_COMMAND, a shell command line that replaces the choice on any desktop
    readonly property string customLock: Quickshell.env("ISLAND_LOCK_COMMAND") || ""
    readonly property var lockCommand: LockCommand.lockCommand(CompositorService.name, root.customLock, root.lockers)

    Process {
        running: true
        command: ["sh", "-c", "for l in \"$@\"; do command -v \"$l\"; done; true", "sh"].concat(LockCommand.lockerNames())
        stdout: StdioCollector {
            onStreamFinished: root.lockers = LockCommand.parseFound(text)
        }
    }

    Process {
        id: sleepProc
        command: ["systemctl", "suspend"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: poweroffProc
        command: ["systemctl", "poweroff"]
    }

    // KDE's power settings module needs Plasma's power management, so it is offered under KDE only
    readonly property bool hasSettings: CompositorService.isKde

    Process {
        id: settingsProc
        command: ["kcmshell6", "kcm_powerdevilprofilesconfig"]
    }

    // Detached: hyprlock stays running until unlocked, and must outlive a shell restart
    function lock() {
        Quickshell.execDetached(root.lockCommand);
    }

    function sleep() {
        sleepProc.running = true;
    }

    function restart() {
        rebootProc.running = true;
    }

    function shutdown() {
        poweroffProc.running = true;
    }

    function openSettings() {
        if (root.hasSettings) settingsProc.running = true;
    }
}
