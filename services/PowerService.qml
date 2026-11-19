pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    Process {
        id: lockProc
        command: ["loginctl", "lock-session"]
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

    function lock() {
        lockProc.running = true;
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
