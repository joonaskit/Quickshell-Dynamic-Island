import "../.."
import QtQuick
import QtQuick.Layouts

// Keys for the shell's own commands in niri's config. Shown in place of the KDE Shortcuts
// page under niri. niri's other binds are edited in niri-settings (docs/NIRI.md).
SettingsCategory {
    id: page

    readonly property bool hasNiriSettings: !DepsService.noneUsable(["niri-settings"])

    // Pick up edits made to config.kdl by hand each time the tab is shown
    onVisibleChanged: {
        if (visible) NiriShortcutService.refresh();
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: !SettingsSearch.active
        spacing: 8

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: NiriShortcutService.error !== ""
                ? NiriShortcutService.error
                : "Click a key to change it, or + to add one. Shortcuts are saved in niri's config"
                  + (NiriShortcutService.path !== "" ? " (" + NiriShortcutService.path + ")" : "")
                  + ", which niri reloads at once."
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: NiriShortcutService.error !== "" ? Theme.accentRed : Theme.textSecondary
        }

        SettingButton {
            visible: NiriShortcutService.conflict !== null
            text: "Use anyway"
            onClicked: NiriShortcutService.forceKey()
        }
    }

    Repeater {
        model: NiriShortcutService.groups

        SettingsSection {
            id: section
            required property var modelData
            title: modelData.name.toUpperCase()
            visible: !SettingsSearch.active || hasMatches

            Repeater {
                model: section.modelData.actions

                NiriShortcutRow {
                    required property var modelData
                    required property int index
                    title: modelData.title
                    detail: modelData.detail
                    keys: NiriShortcutService.keysById[modelData.id] || []
                    showDivider: index < section.modelData.actions.length - 1
                    onCaptured: function(oldKey, newKey) {
                        NiriShortcutService.setKey(modelData.id, oldKey, newKey);
                    }
                    onRemoved: function(key) {
                        NiriShortcutService.removeKey(modelData.id, key);
                    }
                }
            }
        }
    }

    // niri's own actions: focus, layout, workspaces, screenshots...
    SettingsSection {
        key: "niriBinds"
        title: "NIRI"

        RowLayout {
            readonly property bool matchesSearch: SettingsSearch.matches("Edit niri's other key bindings", "niri-settings binds windows workspaces layout screenshot")

            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Edit niri's other key bindings"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: page.hasNiriSettings
                        ? "Windows, layout, workspaces and niri's other actions are set in niri-settings, with a keyboard map and conflict checks"
                        : "Windows, layout, workspaces and niri's other actions are set in niri-settings, which is not installed. Get it from github.com/joonaskit/niri-settings"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textSecondary
                }
            }

            SettingButton {
                text: page.hasNiriSettings ? "Open niri Settings" : "Get niri-settings"
                onClicked: {
                    if (page.hasNiriSettings) WindowService.openNiriSettings("binds");
                    else Qt.openUrlExternally("https://github.com/joonaskit/niri-settings");
                }
            }
        }
    }
}
