import "../.."
import QtQuick

SettingsCategory {

    // Colors
    SettingsSection {
        key: "colors"
        title: "COLORS"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Appearance"
            keywords: "dark light mode theme"
            description: "Light is experimental"
            iconName: "contrast"
            iconColor: Theme.accentIndigo
            currentValue: SettingsService.colorScheme
            options: [
                { label: "Dark", value: "dark" },
                { label: "Light", value: "light" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("colorScheme", val);
            }
        }

        SettingDivider {}

        SettingSwatches {
            title: "Accent Color"
            description: "Used for selection, focus and active states"
            iconName: "sliders"
            iconColor: Theme.accent
            options: Theme.accentChoices
            currentValue: SettingsService.accentColor
            onSelected: function(val) {
                SettingsService.setSetting("accentColor", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Apply to KDE Apps"
            description: KdeThemeService.error !== ""
                ? "Could not apply: " + KdeThemeService.error
                : "Use these colours in KDE apps and in titlebars that follow the colour scheme. Turning it off restores your previous scheme"
            iconName: "contrast"
            iconColor: Theme.accentBlue
            checked: SettingsService.kdeColorScheme
            onToggled: function(val) {
                SettingsService.setSetting("kdeColorScheme", val);
            }
        }

        SettingSegmented {
            title: "KDE Window Background"
            description: Theme.isLight
                ? "For the dark appearance only"
                : "Gray is easier on the eyes in large windows. The island and top bar stay black"
            iconName: "contrast"
            iconColor: Theme.accentIndigo
            isSubOption: true
            enabled: SettingsService.kdeColorScheme && !Theme.isLight
            currentValue: SettingsService.kdeColorBase
            options: [
                { label: "Gray", value: "gray" },
                { label: "Black", value: "black" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("kdeColorBase", val);
            }
        }
    }

    // Screens
    SettingsSection {
        key: "screens"
        title: "SCREENS"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Show On"
            description: "The main screen is the one set as main in KDE System Settings. The island, dock and other windows follow it"
            iconName: "window"
            iconColor: Theme.accentGreen
            currentValue: SettingsService.screenMode
            options: [
                { label: "Main Screen", value: "primary" },
                { label: "All Screens", value: "all" },
                { label: "Choose", value: "named" }
            ]
            onSelected: function(val) {
                if (val === "named" && SettingsService.screenName === "" && ScreenService.primaryScreen)
                    SettingsService.setSetting("screenName", ScreenService.primaryScreen.name);
                SettingsService.setSetting("screenMode", val);
            }
        }

        SettingDivider { visible: !SettingsSearch.active && SettingsService.screenMode === "named" }

        SettingSegmented {
            title: "Screen"
            description: "If it is not connected, the main screen is used"
            iconName: "window"
            iconColor: Theme.accentGreen
            isSubOption: true
            visible: matchesSearch && SettingsService.screenMode === "named"
            currentValue: SettingsService.screenName
            options: ScreenService.screens.map(s => ({ label: s.name, value: s.name }))
            onSelected: function(val) {
                SettingsService.setSetting("screenName", val);
            }
        }
    }

    // Shape
    SettingsSection {
        key: "shape"
        title: "SHAPE"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Corner Roundness"
            keywords: "radius rounded corners"
            description: "How rounded cards, buttons, popups and the dock are. KDE follows the corner radius of your KDE style, currently " + Math.round(Theme.kdeCornerRadius) + "px. Pills and circles stay round"
            iconName: "sliders"
            iconColor: Theme.accentOrange
            currentValue: SettingsService.cornerStyle
            options: Theme.cornerChoices.map(c => ({ label: c.label, value: c.name }))
            onSelected: function(val) {
                SettingsService.setSetting("cornerStyle", val);
            }
        }
    }

    // Pill style
    SettingsSection {
        key: "pills"
        title: "PILLS"
        titlePixelSize: Theme.fontPx(10)

        SettingSegmented {
            title: "Pill Style"
            keywords: "notch floating top bar macbook"
            description: "Floating pills hang below the top edge. Notch pills hug it with a flat top and soft curves into the screen edge, like the MacBook notch"
            iconName: "window"
            iconColor: Theme.accentCyan
            currentValue: SettingsService.pillStyle
            options: [
                { label: "Floating", value: "floating" },
                { label: "Notch", value: "notch" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("pillStyle", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Tuck Side Pills"
            keywords: "notch tabs folder"
            description: "The app tray and virtual desktops sit half behind their neighbours and slide out under the pointer. Notch style only"
            iconName: "pin"
            iconColor: Theme.accentPurple
            isSubOption: true
            enabled: SettingsService.pillStyle === "notch"
            checked: SettingsService.tuckPills
            onToggled: function(val) { SettingsService.setSetting("tuckPills", val); }
        }

        SettingDivider {}

        SettingToggle {
            title: "Frosted Status Icons"
            keywords: "glass blur transparent"
            description: "Give the status icons the see-through frosted look of the app tray and virtual desktops instead of solid. Their menus stay solid"
            iconName: "sliders"
            iconColor: Theme.accentBlue
            checked: SettingsService.frostedStatusIcons
            onToggled: function(val) { SettingsService.setSetting("frostedStatusIcons", val); }
        }
    }

    // Display & Scaling (DPI)
    SettingsSection {
        key: "scaling"
        title: "DISPLAY & SCALING (DPI)"
        subtitle: "Interface & Font Sizing"
        titlePixelSize: Theme.fontPx(10)

        // 1. Interface Scale (DPI)
        SettingSlider {
            title: "Interface Scale (DPI)"
            description: "Scale elements, islands, status bar pills, dock, and popup geometry (80% - 125%)"
            iconName: "sliders"
            iconColor: Theme.accentCyan
            value: SettingsService.uiScale
            minimumValue: 0.80
            maximumValue: 1.25
            stepSize: 0.05
            presets: [
                { label: "80%", value: 0.80 },
                { label: "90%", value: 0.90 },
                { label: "100% (Default)", value: 1.00 },
                { label: "110%", value: 1.10 },
                { label: "125%", value: 1.25 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("uiScale", val);
            }
        }

        SettingDivider {}

        // 2. Text & Font Size Scale
        SettingSlider {
            title: "Text & Font Size"
            description: "Proportionally scale clock digits, labels, titles, and text elements (85% - 125%)"
            iconName: "type"
            iconColor: Theme.accentYellow
            value: SettingsService.fontScale
            minimumValue: 0.85
            maximumValue: 1.25
            stepSize: 0.05
            presets: [
                { label: "85%", value: 0.85 },
                { label: "90%", value: 0.90 },
                { label: "100% (Default)", value: 1.00 },
                { label: "110%", value: 1.10 },
                { label: "125%", value: 1.25 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("fontScale", val);
            }
        }
    }

    // Fonts
    SettingsSection {
        key: "fonts"
        title: "FONTS"
        titlePixelSize: Theme.fontPx(10)

        SettingFontPicker {
            title: "Interface Font"
            description: "Font for labels and text. Missing fonts fall back to the defaults"
            iconName: "type"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.fontFamily
            defaultLabel: "Default (Cantarell)"
            onSelected: function(val) {
                SettingsService.setSetting("fontFamily", val);
            }
        }

        SettingDivider {}

        SettingFontPicker {
            title: "Display Font"
            description: "Font for the clock, titles and large numbers"
            iconName: "type"
            iconColor: Theme.accentPurple
            currentValue: SettingsService.fontDisplayFamily
            defaultLabel: "Same as interface font"
            onSelected: function(val) {
                SettingsService.setSetting("fontDisplayFamily", val);
            }
        }
    }
}
