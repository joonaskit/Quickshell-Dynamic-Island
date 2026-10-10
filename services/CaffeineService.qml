pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Whether caffeine is on. Remembered in settings.json (SettingsService.caffeineEnabled)
    // and taken again when the shell starts, so a restart or reload keeps it on.
    // It is restored after a reboot too: the setting is the user's last choice, and
    // the icon shows when it is on.
    property bool isActive: false
    property bool restored: false
    property string screenSaverCookie: ""
    property string powerManagementCookie: ""

    // Background process holding systemd-inhibit idle & sleep block
    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Island Caffeine", "--why=Prevent screen dimming and shutdown", "sleep", "infinity"]
    }

    // Process to call DBus Inhibit on FreeDesktop / KDE ScreenSaver
    Process {
        id: ssInhibitProc
        command: ["qdbus-qt6", "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver.Inhibit", "Caffeine", "Prevent screen dimming"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    root.screenSaverCookie = text.trim();
                }
            }
        }
    }

    // Process to call DBus Inhibit on FreeDesktop / KDE PowerManagement
    Process {
        id: pmInhibitProc
        command: ["qdbus-qt6", "org.freedesktop.PowerManagement.Inhibit", "/org/freedesktop/PowerManagement/Inhibit", "org.freedesktop.PowerManagement.Inhibit.Inhibit", "Caffeine", "Prevent screen dimming and sleep"]
        stdout: StdioCollector {
            onTextChanged: {
                if (text.length > 0) {
                    root.powerManagementCookie = text.trim();
                }
            }
        }
    }

    // Process to call DBus UnInhibit when Caffeine is deactivated
    Process {
        id: unInhibitProc
    }

    function toggle() {
        if (root.isActive) {
            root.disable();
        } else {
            root.enable();
        }
    }

    // Takes the shell's saved state once the settings have loaded
    Connections {
        target: SettingsService
        function onSettingsChanged() {
            if (!SettingsService.isLoaded || root.restored) return;
            root.restored = true;
            if (SettingsService.caffeineEnabled && !root.isActive) root.startInhibit();
        }
    }

    function enable() {
        root.restored = true;
        root.startInhibit();
        SettingsService.setSetting("caffeineEnabled", true);
    }

    function startInhibit() {
        root.isActive = true;
        inhibitProc.running = true;
        ssInhibitProc.running = true;
        pmInhibitProc.running = true;
    }

    function disable() {
        SettingsService.setSetting("caffeineEnabled", false);
        root.isActive = false;
        inhibitProc.running = false;

        let cmd = "";
        if (root.screenSaverCookie !== "") {
            cmd += "qdbus-qt6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.UnInhibit " + root.screenSaverCookie + " 2>/dev/null; ";
            root.screenSaverCookie = "";
        }
        if (root.powerManagementCookie !== "") {
            cmd += "qdbus-qt6 org.freedesktop.PowerManagement.Inhibit /org/freedesktop/PowerManagement/Inhibit org.freedesktop.PowerManagement.Inhibit.UnInhibit " + root.powerManagementCookie + " 2>/dev/null; ";
            root.powerManagementCookie = "";
        }
        if (cmd.length > 0) {
            unInhibitProc.command = ["sh", "-c", cmd];
            unInhibitProc.running = true;
        }
    }
}
