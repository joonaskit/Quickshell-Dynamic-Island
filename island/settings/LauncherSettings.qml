import "../.."
import QtQuick

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
}
