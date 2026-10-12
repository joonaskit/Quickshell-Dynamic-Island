pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// Export and import of the configuration through scripts/settings_backup.py,
// which does the validation and the file work. This picks the file, runs the
// script and makes the services re-read their files after an import.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/settings_backup.py"

    // What the next export or import covers. The launcher history is personal, so it is off until chosen
    property bool includeSettings: true
    property bool includeDock: true
    property bool includeUsage: false
    readonly property string sections: {
        let names = [];
        if (root.includeSettings) names.push("settings");
        if (root.includeDock) names.push("dock");
        if (root.includeUsage) names.push("usage");
        return names.join(",");
    }

    // False when neither kdialog nor zenity is installed; the settings page then asks for a typed path
    property bool pickerAvailable: true
    readonly property bool busy: pickProc.running || runProc.running

    // Result of the last export or import
    property string notice: ""
    property bool noticeIsError: false

    // "export" or "import", for the file dialog that is open and the script run that follows
    property string action: ""

    function reloadConfig() {
        SettingsService.reloadFromDisk();
        DockService.reloadConfig();
    }

    function showNotice(message, isError) {
        root.notice = message;
        root.noticeIsError = !!isError;
    }

    // Opens a file dialog, then exports or imports the chosen file
    function pick(action) {
        if (root.busy) return;
        if (root.sections === "") {
            root.showNotice("Choose at least one thing to include", true);
            return;
        }
        root.action = action;
        let name = "\"$HOME/quickshell-island-config.json\"";
        pickProc.command = ["sh", "-c", action === "export"
            ? "if command -v kdialog >/dev/null; then kdialog --getsavefilename " + name + " 'JSON files (*.json)'; else zenity --file-selection --save --confirm-overwrite --filename=" + name + "; fi"
            : "if command -v kdialog >/dev/null; then kdialog --getopenfilename \"$HOME\" 'JSON files (*.json)'; else zenity --file-selection; fi"];
        pickProc.running = true;
    }

    // Exports to or imports from a path directly ("~" is expanded by the script)
    function run(action, path) {
        if (runProc.running) return;
        path = String(path).trim();
        if (path === "") {
            root.showNotice("Enter the path of a file", true);
            return;
        }
        if (root.sections === "") {
            root.showNotice("Choose at least one thing to include", true);
            return;
        }
        root.action = action;
        runProc.command = ["python3", root.script, action, path, "--json", "--sections", root.sections];
        runProc.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v kdialog >/dev/null || command -v zenity >/dev/null"]
        onExited: function(exitCode) {
            root.pickerAvailable = exitCode === 0;
        }
    }

    Process {
        id: pickProc
        stdout: StdioCollector {
            onStreamFinished: {
                // Empty when the dialog was cancelled
                let path = text.trim();
                if (path !== "") root.run(root.action, path);
            }
        }
    }

    Process {
        id: runProc
        stdout: StdioCollector {
            onStreamFinished: {
                let result = null;
                try {
                    result = JSON.parse(text.trim());
                } catch (e) {}
                if (!result) {
                    root.showNotice("The " + root.action + " did not finish", true);
                    return;
                }
                if (!result.ok) {
                    root.showNotice("Failed: " + result.error, true);
                    return;
                }
                if (root.action === "export") {
                    root.showNotice("Exported to " + result.file, false);
                    return;
                }
                root.reloadConfig();
                let message = "Imported " + result.sections.join(", ") + ".";
                if (result.backup) message += " The previous files are in " + result.backup + ".";
                if (result.warnings.length > 0) message += " " + result.warnings.join(". ") + ".";
                root.showNotice(message, false);
            }
        }
    }
}
