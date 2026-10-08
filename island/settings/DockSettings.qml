import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Dock Behavior
    SettingsSection {
        title: "DOCK"

        // 1. Dock Screen Edge Position
        SettingSegmented {
            title: "Dock Position"
            description: "Screen edge where the dock is pinned (Bottom, Left, or Right)"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            currentValue: SettingsService.dockPosition
            options: [
                { label: "Bottom", value: "bottom" },
                { label: "Left", value: "left" },
                { label: "Right", value: "right" }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("dockPosition", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // 2. Dock Base Icon Size Slider
        SettingSlider {
            title: "Dock Icon Size"
            description: "Base icon dimension in the dock capsule (36px – 64px)"
            iconName: "sliders"
            iconColor: Theme.accentCyan
            value: SettingsService.dockIconSize
            minimumValue: 36
            maximumValue: 64
            stepSize: 2
            valueDisplay: SettingsService.dockIconSize + "px"
            presets: [
                { label: "36px", value: 36 },
                { label: "44px (Default)", value: 44 },
                { label: "52px", value: 52 },
                { label: "64px", value: 64 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("dockIconSize", Math.round(val));
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // 3. Hover Magnification Scale Slider
        SettingSlider {
            title: "Hover Magnification"
            description: "Cursor proximity wave zoom effect (1.0x = disabled, up to 1.5x)"
            iconName: "search"
            iconColor: Theme.accentPurple
            value: SettingsService.dockScaleHover
            minimumValue: 1.00
            maximumValue: 1.50
            stepSize: 0.01
            valueDisplay: SettingsService.dockScaleHover <= 1.01 ? "Disabled" : (SettingsService.dockScaleHover.toFixed(2) + "x")
            presets: [
                { label: "Disabled", value: 1.00 },
                { label: "1.15x", value: 1.15 },
                { label: "1.28x (Default)", value: 1.28 },
                { label: "1.40x", value: 1.40 },
                { label: "1.50x", value: 1.50 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("dockScaleHover", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SettingToggle {
            title: "Auto-Hide Dock on Fullscreen"
            description: "Automatically hides the dock when games or fullscreen apps are active"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            checked: SettingsService.dockAutoHideOnFullscreen
            onToggled: function(val) {
                SettingsService.setSetting("dockAutoHideOnFullscreen", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SettingToggle {
            title: "Auto-Hide Dock from Windows"
            description: "Automatically drops the dock down when a window moves over or overlaps its area"
            iconName: "window"
            iconColor: Theme.accentBlue
            checked: SettingsService.dockAutoHideFromWindows
            onToggled: function(val) {
                SettingsService.setSetting("dockAutoHideFromWindows", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SettingToggle {
            title: "Always Auto-Hide Dock"
            description: "Keeps the dock hidden off-screen until you hover over its screen edge"
            iconName: "chevron-down"
            iconColor: Theme.accentCyan
            checked: SettingsService.dockAutoHideAlways
            onToggled: function(val) {
                SettingsService.setSetting("dockAutoHideAlways", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SettingToggle {
            title: "Show Dock Border"
            description: "Display a subtle border outline and top highlight on the dock capsule"
            iconName: "square"
            iconColor: Theme.accentPurple
            checked: SettingsService.dockShowBorder
            onToggled: function(val) {
                SettingsService.setSetting("dockShowBorder", val);
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SettingToggle {
            title: "Transparent Glass Dock"
            description: "Use a translucent frosted glass effect with specular highlights for the dock capsule"
            iconName: "contrast"
            iconColor: Theme.accentIndigo
            checked: SettingsService.dockTransparent
            onToggled: function(val) {
                SettingsService.setSetting("dockTransparent", val);
            }
        }

        SettingDivider {}

        SettingSwatches {
            title: "Dock & Launcher Tint"
            description: "Hue of the dock, the launcher and the dock's menus"
            iconName: "contrast"
            iconColor: Theme.accentPurple
            options: Theme.dockTintChoices
            currentValue: SettingsService.dockTint
            onSelected: function(val) {
                SettingsService.setSetting("dockTint", val);
            }
        }

        SettingDivider {}

        // Only the hue options are mixed in; Cool and Neutral are fixed colors
        SettingSlider {
            title: "Tint Intensity"
            description: Theme.dockTintHasHue ? "How strongly the chosen hue colors the dock and launcher" : "Pick a hue above to adjust its intensity"
            iconName: "sliders"
            iconColor: Theme.accentPurple
            enabled: Theme.dockTintHasHue
            opacity: enabled ? 1.0 : 0.4
            value: SettingsService.dockTintStrength
            minimumValue: 0.02
            maximumValue: 0.20
            stepSize: 0.01
            presets: [
                { label: "Subtle", value: 0.04 },
                { label: "8% (Default)", value: 0.08 },
                { label: "Strong", value: 0.14 },
                { label: "Vivid", value: 0.20 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting("dockTintStrength", val);
            }
        }

        SettingDivider {}

        // One slider, two remembered values: the solid dock and the glass dock
        // each keep their own opacity
        SettingSlider {
            title: "Dock Opacity"
            description: SettingsService.dockTransparent ? "Opacity of the transparent glass dock" : "Opacity of the dock (the launcher and menus stay readable)"
            iconName: "contrast"
            iconColor: Theme.accentIndigo
            value: SettingsService.dockTransparent ? SettingsService.dockGlassOpacity : SettingsService.dockOpacity
            minimumValue: 0.20
            maximumValue: 1.00
            stepSize: 0.05
            presets: SettingsService.dockTransparent ? [
                { label: "20%", value: 0.20 },
                { label: "35% (Default)", value: 0.35 },
                { label: "50%", value: 0.50 },
                { label: "70%", value: 0.70 }
            ] : [
                { label: "60%", value: 0.60 },
                { label: "85% (Default)", value: 0.85 },
                { label: "95%", value: 0.95 },
                { label: "Solid", value: 1.00 }
            ]
            onValueModified: function(val) {
                SettingsService.setSetting(SettingsService.dockTransparent ? "dockGlassOpacity" : "dockOpacity", val);
            }
        }
    }
}
