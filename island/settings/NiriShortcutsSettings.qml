import "../.."
import QtQuick
import QtQuick.Layouts

// niri's keyboard shortcuts, one tab per group of actions. Shown in place of the KDE
// Shortcuts page when the shell runs under niri; while searching every group shows.
SettingsCategory {
    id: page

    property string currentGroup: "Shell"

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

    // Group tabs
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        visible: !SettingsSearch.active
        radius: Theme.corner(8)
        color: Theme.overlay(0.08)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2

            Repeater {
                model: NiriShortcutService.groups

                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool isSelected: page.currentGroup === modelData.name
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.corner(6)
                    color: isSelected ? Theme.overlay(0.22) : (tabMouse.containsMouse ? Theme.overlay(0.06) : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    Text {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 8)
                        text: tab.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: tab.isSelected ? Font.Bold : Font.Normal
                        color: tab.isSelected ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.currentGroup = tab.modelData.name
                    }
                }
            }
        }
    }

    Repeater {
        model: NiriShortcutService.groups

        SettingsSection {
            id: section
            required property var modelData
            title: modelData.name.toUpperCase()
            visible: SettingsSearch.active ? hasMatches : page.currentGroup === modelData.name

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
}
