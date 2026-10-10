import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {
    // Pick up changes made in KDE's own settings each time the tab is shown
    onVisibleChanged: {
        if (visible) ShortcutService.refresh();
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: !SettingsSearch.active
        wrapMode: Text.WordWrap
        text: ShortcutService.error !== ""
            ? ShortcutService.error
            : "Click a box and press the keys you want. Shortcuts are saved in KDE's settings and also appear in System Settings under Shortcuts."
        font.family: Theme.fontFamily
        font.pixelSize: 10
        color: ShortcutService.error !== "" ? Theme.accentRed : Theme.textSecondary
    }

    Repeater {
        model: ShortcutService.groups

        SettingsSection {
            id: section
            required property var modelData
            title: modelData.name.toUpperCase()

            Repeater {
                model: section.modelData.actions

                SettingShortcut {
                    id: shortcut
                    required property var modelData
                    required property int index
                    title: modelData.title
                    description: modelData.command
                    keysText: ShortcutService.keysById[modelData.id] || ""
                    showDivider: index < section.modelData.actions.length - 1
                    onCaptured: function(code) {
                        ShortcutService.setShortcut(modelData.id, code);
                    }
                    onCleared: ShortcutService.clearShortcut(modelData.id)
                }
            }
        }
    }
}
