import QtQuick
import Quickshell
import Quickshell.Io
import "fixture"

// SettingsService keeps settings.json in $ISLAND_CONFIG_DIR, not in the shell folder,
// and creates that folder on the first save (docs/SETTINGS.md)
ShellRoot {
    id: root

    readonly property string dir: Quickshell.env("ISLAND_CONFIG_DIR")

    // Read with a command: a file watch cannot be set on a folder that does not exist yet
    Process {
        id: reader
        property string text: ""
        command: ["sh", "-c", "cat \"$ISLAND_CONFIG_DIR/settings.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: reader.text = this.text
        }
    }

    function savedScale() {
        if (!reader.running) reader.running = true;
        try {
            return JSON.parse(reader.text).uiScale;
        } catch (e) {
            return undefined;
        }
    }

    Steps {
        id: steps
        steps: [
            {
                name: "path",
                until: () => steps.expect("configDir", SettingsService.configDir, root.dir)
                    && steps.expect("settingsFilePath", SettingsService.settingsFilePath, root.dir + "/settings.json")
            },
            { name: "loaded on defaults", until: () => SettingsService.isLoaded },
            {
                name: "saved into a new folder",
                run: () => SettingsService.setSetting("uiScale", 1.25),
                until: () => root.savedScale() === 1.25
            },
            {
                name: "nothing beside the shell",
                until: () => steps.expect("shell folder has settings.json", SettingsService.settingsFilePath.indexOf(Quickshell.shellDir) === 0, false)
            }
        ]
    }
}
