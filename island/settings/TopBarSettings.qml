import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {
    id: page

    // Status icon row: a toggle, or for an icon that shows only when needed a choice,
    // with move buttons. Moves stay within the icon's group
    component StatusIconRow: ColumnLayout {
        id: iconRow
        required property var modelData
        required property int index
        readonly property bool hasPin: !!modelData.pinKey
        readonly property bool matchesSearch: iconToggle.matchesSearch

        Layout.fillWidth: true
        visible: matchesSearch
        spacing: 0

        SettingDivider {
            visible: iconRow.index > 0 && !SettingsSearch.active
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            SettingToggle {
                id: iconToggle
                visible: matchesSearch && !iconRow.hasPin
                title: iconRow.modelData.title
                description: iconRow.modelData.description
                warning: DepsService.iconProblem(iconRow.modelData.id)
                iconName: iconRow.modelData.icon
                iconColor: iconRow.modelData.iconColor
                checked: SettingsService[iconRow.modelData.settingKey]
                onToggled: function(val) {
                    SettingsService.setSetting(iconRow.modelData.settingKey, val);
                }
            }

            SettingChoice {
                visible: matchesSearch && iconRow.hasPin
                title: iconRow.modelData.title
                description: iconRow.modelData.description
                warning: DepsService.iconProblem(iconRow.modelData.id)
                iconName: iconRow.modelData.icon
                iconColor: iconRow.modelData.iconColor
                options: [
                    { "label": "Off", "value": "off" },
                    { "label": "When Needed", "value": "on" },
                    { "label": "Always", "value": "sub" }
                ]
                currentValue: iconRow.hasPin ? SettingsService.pairValue(iconRow.modelData.settingKey, iconRow.modelData.pinKey) : "off"
                onSelected: function(val) {
                    SettingsService.setPair(iconRow.modelData.settingKey, iconRow.modelData.pinKey, val);
                }
            }

            SettingMoveButtons {
                visible: !SettingsSearch.active
                Layout.rightMargin: 10
                canMoveUp: SettingsService.canMoveStatusIcon(iconRow.modelData.id, -1)
                canMoveDown: SettingsService.canMoveStatusIcon(iconRow.modelData.id, 1)
                onMoved: function(delta) {
                    SettingsService.moveStatusIcon(iconRow.modelData.id, delta);
                }
            }
        }
    }

    readonly property var pillOptions: [
        { "label": "Off", "value": "off" },
        { "label": "Show", "value": "on" },
        { "label": "Auto-Hide", "value": "sub" }
    ]

    TopBarDiagram {}

    // When the pills flatten into the full-width bar, and hiding it
    SettingsSection {
        key: "topBar"
        title: "TOP BAR"

        SettingSegmented {
            title: "Full-Width Bar"
            keywords: "panel morph maximized maximize tiling tiled gnome always top bar mode"
            description: "When the pills join into one bar along the top edge. Always suits tiling layouts"
            iconName: "window"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.topBarMode
            options: [
                { "label": "Never", "value": "island" },
                { "label": "With Maximized Windows", "value": "maximized" },
                { "label": "Always", "value": "always" }
            ]
            onSelected: function(val) {
                SettingsService.setTopBarMode(val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Keep Windows Below the Bar"
            keywords: "reserve space exclusive zone overlap maximized"
            description: "Reserve the bar's height so maximized windows start under it"
            iconName: "maximize"
            iconColor: Theme.accentCyan
            isSubOption: true
            enabled: SettingsService.topBarMode !== "island" && !SettingsService.autoHideTopBar
            checked: SettingsService.reserveSpaceWhenMaximized
            onToggled: function(val) {
                SettingsService.setSetting("reserveSpaceWhenMaximized", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Keep Windows Below the Island"
            keywords: "reserve space exclusive zone overlap gap margin tiling tiled floating"
            description: "Reserve a gap under the pills while the full-width bar is off, so tiled windows never sit under them"
            iconName: "maximize"
            iconColor: Theme.accentCyan
            enabled: SettingsService.topBarMode !== "always" && !SettingsService.autoHideTopBar
            checked: SettingsService.reserveSpaceWithoutBar
            onToggled: function(val) {
                SettingsService.setSetting("reserveSpaceWithoutBar", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Auto-Hide"
            keywords: "top bar hide reveal panel edge"
            description: "Slide everything off screen until the pointer rests at the top edge"
            iconName: "chevron-up"
            iconColor: Theme.accentCyan
            checked: SettingsService.autoHideTopBar
            onToggled: function(val) {
                SettingsService.setSetting("autoHideTopBar", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Hide in Fullscreen"
            keywords: "games video fullscreen top bar"
            description: "Hide the island and pills while a game or video is fullscreen"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            checked: SettingsService.hideOnFullscreen
            onToggled: function(val) {
                SettingsService.setSetting("hideOnFullscreen", val);
            }
        }
    }

    // Window controls and virtual desktops on the left, the app tray on the right
    SettingsSection {
        key: "pills"
        title: "SIDE PILLS"
        subtitle: "Auto-hide pills show when the pointer rests at the top edge"

        SettingChoice {
            title: "Window Controls"
            keywords: "pill autohide title app name menu close minimize"
            description: "Active app, window title and window actions"
            iconName: "window"
            iconColor: Theme.accentBlue
            options: page.pillOptions
            currentValue: SettingsService.pairValue("showWindowControls", "autoHideWindowControls")
            onSelected: function(val) {
                SettingsService.setPair("showWindowControls", "autoHideWindowControls", val);
            }
        }

        SettingDivider {}

        SettingChoice {
            title: "Virtual Desktops"
            keywords: "pill autohide workspaces switcher"
            description: "Desktop switcher and desktop actions"
            iconName: "desktop"
            iconColor: Theme.accentPurple
            options: page.pillOptions
            currentValue: SettingsService.pairValue("showVirtualDesktops", "autoHideVirtualDesktops")
            onSelected: function(val) {
                SettingsService.setPair("showVirtualDesktops", "autoHideVirtualDesktops", val);
            }
        }

        SettingDivider {}

        SettingChoice {
            title: "App Tray"
            keywords: "pill autohide system tray background apps indicators"
            description: "Tray icons of apps running in the background"
            iconName: "desktop"
            iconColor: Theme.accentIndigo
            options: page.pillOptions
            currentValue: SettingsService.pairValue("showAppTrayPill", "autoHideAppTrayPill")
            onSelected: function(val) {
                SettingsService.setPair("showAppTrayPill", "autoHideAppTrayPill", val);
            }
        }
    }

    // Status icons on the right, in display order
    SettingsSection {
        key: "statusIcons"
        title: "STATUS ICONS"
        subtitle: "Left to right"

        Repeater {
            model: SettingsService.orderedStatusIcons.filter(i => i.group === "system")
            delegate: StatusIconRow {}
        }

        SettingDivider {}

        SettingToggle {
            title: "Hide Icons With Missing Tools"
            keywords: "status icons dependencies not installed dimmed"
            description: "Icons whose tools are not installed are dimmed. Turn on to hide them instead"
            iconName: "alert"
            iconColor: Theme.accentOrange
            checked: SettingsService.hideUnavailableIcons
            onToggled: function(val) {
                SettingsService.setSetting("hideUnavailableIcons", val);
            }
        }
    }

    // Optional icons, off until turned on; drawn before the status icons
    SettingsSection {
        key: "optionalIcons"
        title: "OPTIONAL ICONS"
        subtitle: "Shown left of the status icons"

        Repeater {
            model: SettingsService.orderedStatusIcons.filter(i => i.group === "widgets")
            delegate: StatusIconRow {}
        }
    }
}
