import "../.."
import QtQuick
import QtQuick.Layouts
import "../../services/launcherExtras.js" as LauncherExtras

SettingsCategory {

    // App Launcher Customization
    SettingsSection {
        title: "APP LAUNCHER"

        // 1. Default View Layout (Grid vs List)
        SettingSegmented {
            title: "Default View Layout"
            description: "Visual layout for the application picker (Grid or List)"
            iconName: "apps"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.launcherDefaultView
            options: [
                { label: "Grid View", value: "grid" },
                { label: "List View", value: "list" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("launcherDefaultView", val);
            }
        }

        SettingDivider {}

        // Start tab
        SettingSegmented {
            title: "Open On"
            description: "Tab shown when the launcher opens (Recent and Frequent fall back to All until you have launched something)"
            iconName: "clock"
            iconColor: Theme.accentOrange
            currentValue: SettingsService.launcherStartTab
            options: [
                { label: "All", value: "All" },
                { label: "Recent", value: "Recent" },
                { label: "Frequent", value: "Frequent" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("launcherStartTab", val);
            }
        }

        SettingDivider {}

        // 2. Display Density (Comfortable vs Compact)
        SettingSegmented {
            title: "Display Density"
            description: "Tile size, spacing, and icon dimension density"
            iconName: "sliders"
            iconColor: Theme.accentCyan
            currentValue: SettingsService.launcherDensity
            options: [
                { label: "Comfortable", value: "comfortable" },
                { label: "Compact", value: "compact" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("launcherDensity", val);
            }
        }

        SettingDivider {}

        // 3. Grid Columns (3, 4, 5)
        SettingSegmented {
            title: "Grid Columns"
            description: "Number of columns when Grid View is active"
            iconName: "grid"
            iconColor: Theme.accentPurple
            currentValue: SettingsService.launcherGridColumns
            options: [
                { label: "3 Cols", value: 3 },
                { label: "4 Cols", value: 4 },
                { label: "5 Cols", value: 5 }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("launcherGridColumns", parseInt(val));
            }
        }

        SettingDivider {}

        // 4. Category Filter Tabs Toggle
        SettingToggle {
            title: "Category Filter Bar"
            description: "Display category tabs (Internet, Development, Media, System...) to filter apps"
            iconName: "tag"
            iconColor: Theme.accentOrange
            checked: SettingsService.launcherShowCategories
            onToggled: function(val) {
                SettingsService.setSetting("launcherShowCategories", val);
            }
        }

        SettingDivider {}

        // 5. Show App Generic Names / Descriptions Toggle
        SettingToggle {
            title: "Show App Subtitles"
            description: "Display generic descriptions (e.g. 'Web Browser') under app titles"
            iconName: "type"
            iconColor: Theme.accentGreen
            checked: SettingsService.launcherShowGenericNames
            onToggled: function(val) {
                SettingsService.setSetting("launcherShowGenericNames", val);
            }
        }
    }

    // Instant answers typed into the search box
    SettingsSection {
        title: "SEARCH EXTRAS"
        subtitle: "Answers shown above the apps. Enter runs them"

        SettingToggle {
            title: "Calculator"
            description: "Type a sum such as 2*(3+4) or sqrt(16). Enter copies the result"
            iconName: "bolt"
            iconColor: Theme.accentBlue
            checked: SettingsService.launcherCalculator
            onToggled: function(val) { SettingsService.setSetting("launcherCalculator", val); }
        }

        SettingDivider {}

        SettingToggle {
            title: "Unit Conversion"
            description: "Type 5 km in mi, 100 c to f or 2 gib in mib. Lengths, weights, volumes, speeds, times, data sizes, areas and temperatures"
            iconName: "refresh"
            iconColor: Theme.accentCyan
            checked: SettingsService.launcherConversion
            onToggled: function(val) { SettingsService.setSetting("launcherConversion", val); }
        }

        SettingDivider {}

        SettingToggle {
            title: "Web Search Shortcuts"
            description: "Type a shortcut and a search, such as g cats. Enter opens it in the default browser"
            iconName: "search"
            iconColor: Theme.accentGreen
            checked: SettingsService.launcherWebSearch
            onToggled: function(val) { SettingsService.setSetting("launcherWebSearch", val); }
        }

        ColumnLayout {
            id: shortcutsEditor

            readonly property bool matchesSearch: SettingsSearch.matches("Web search shortcuts list", "google wikipedia duckduckgo url")

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 4
            Layout.bottomMargin: 10
            visible: SettingsService.launcherWebSearch && matchesSearch
            spacing: 6

            Text {
                text: "Shortcuts, one per line: key | name | address. %s stands for the search."
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: shortcutsText.implicitHeight + 16
                radius: Theme.corner(8)
                color: Theme.overlay(0.05)
                border.width: 1
                border.color: shortcutsText.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                TextEdit {
                    id: shortcutsText
                    anchors.fill: parent
                    anchors.margins: 8
                    wrapMode: TextEdit.WrapAnywhere
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textPrimary
                    selectionColor: Theme.accentTint(0.4)
                    selectedTextColor: Theme.textPrimary
                    selectByMouse: true
                    text: LauncherExtras.formatShortcuts(SettingsService.launcherWebShortcuts)

                    // Saved when the box loses focus. Lines that are not valid, or whose address
                    // is not http or https, are dropped.
                    onActiveFocusChanged: {
                        if (activeFocus) return;
                        SettingsService.setSetting("launcherWebShortcuts", LauncherExtras.parseShortcuts(text));
                        text = Qt.binding(function() { return LauncherExtras.formatShortcuts(SettingsService.launcherWebShortcuts); });
                    }
                }
            }

            Text {
                text: "Only http and https addresses are used. Lines that do not fit the format are dropped when you leave the box."
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textTertiary
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "File Search"
            description: "Type " + SettingsService.launcherFileSearchKey + " and a name, such as " + SettingsService.launcherFileSearchKey + " report 2024, to find files and folders by name. Enter opens one, Alt+Enter shows it in its folder. Uses Filehouse" + (FileSearchService.available ? "" : ", which is not installed")
            iconName: "folder"
            iconColor: Theme.accentOrange
            checked: SettingsService.launcherFileSearch
            onToggled: function(val) { SettingsService.setSetting("launcherFileSearch", val); }
        }

        ColumnLayout {
            readonly property bool matchesSearch: SettingsSearch.matches("File search folder", "filehouse root where to look")

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 4
            Layout.bottomMargin: 10
            visible: SettingsService.launcherFileSearch && matchesSearch
            spacing: 6

            Text {
                text: "Folder to search in. Hidden files and folders are left out."
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: Theme.corner(8)
                color: Theme.overlay(0.05)
                border.width: 1
                border.color: rootInput.activeFocus ? Theme.accentTint(0.6) : Theme.overlay(0.08)

                TextInput {
                    id: rootInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textPrimary
                    selectionColor: Theme.accentTint(0.4)
                    selectedTextColor: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    text: SettingsService.launcherFileSearchRoot

                    // Saved on Enter or when the field loses focus; an empty field goes back to home
                    onEditingFinished: {
                        SettingsService.setSetting("launcherFileSearchRoot", text.trim() === "" ? "~" : text.trim());
                        text = Qt.binding(function() { return SettingsService.launcherFileSearchRoot; });
                    }
                }
            }
        }
    }
}
