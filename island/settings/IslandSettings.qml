import "../.."
import QtQuick
import QtQuick.Layouts

SettingsCategory {

    // Expanded Island Cards Customization
    SettingsSection {
        title: "EXPANDED ISLAND CARDS"
        subtitle: "Choose cards shown when expanded"

        // Timer & Stopwatch
        SettingToggle {
            title: "Timer & Stopwatch"
            description: "Countdown timer and stopwatch card"
            iconName: "clock"
            iconColor: Theme.accentOrange
            checked: SettingsService.showExpandedTimer
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedTimer", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Timer in Island"
            description: "Show a running timer or stopwatch in the compact island"
            iconName: "clock"
            iconColor: Theme.accentOrange
            checked: SettingsService.showTimerInPill
            onToggled: function(val) {
                SettingsService.setSetting("showTimerInPill", val);
            }
        }

        SettingDivider {}

        // 1. Mini Calendar
        SettingToggle {
            title: "Mini Calendar"
            description: "Monthly calendar grid with current date highlight and week numbers"
            iconName: "calendar"
            iconColor: Theme.accentRed
            checked: SettingsService.showExpandedCalendar
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedCalendar", val);
            }
        }

        SettingDivider {}

        // 2. Media Player
        SettingToggle {
            title: "Media Player"
            description: "Playback controls, album artwork, track title, and interactive seek bar"
            iconName: "music"
            iconColor: Theme.accentRed
            checked: SettingsService.showExpandedMedia
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedMedia", val);
            }
        }

        SettingDivider {}

        // 3. Audio Output Selector
        SettingToggle {
            title: "Audio Output Selector"
            description: "Quickly switch active audio playback device (speakers, headphones, HDMI)"
            iconName: "headphones"
            iconColor: Theme.accentBlue
            checked: SettingsService.showExpandedAudioSink
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedAudioSink", val);
            }
        }

        SettingDivider {}

        // 4. Volume Slider
        SettingToggle {
            title: "App Volume Mixer"
            description: "Per-app volume sliders for apps that are playing audio"
            iconName: "music"
            iconColor: Theme.accentBlue
            checked: SettingsService.showExpandedAppMixer
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedAppMixer", val);
            }
        }

        SettingDivider {}

        SettingToggle {
            title: "Volume Slider"
            description: "Interactive slider for master speaker output volume"
            iconName: "volume-high"
            iconColor: Theme.accentGreen
            checked: SettingsService.showExpandedVolume
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedVolume", val);
            }
        }

        SettingDivider {}

        // 5. Brightness Slider
        SettingToggle {
            title: "Brightness Slider"
            description: "Interactive slider for screen backlight brightness"
            iconName: "brightness-high"
            iconColor: Theme.accentYellow
            checked: SettingsService.showExpandedBrightness
            onToggled: function(val) {
                SettingsService.setSetting("showExpandedBrightness", val);
            }
        }
    }

    // Island Behavior & Timing
    SettingsSection {
        title: "ISLAND BEHAVIOR & TIMING"
        subtitle: "Morphing, full-screen & auto-collapse"

        // 1. Show Media When Playing
        SettingToggle {
            title: "Show Media Playing in Compact Pill"
            description: "Morphs compact pill into media status when music or audio is playing"
            iconName: "music"
            iconColor: Theme.accentRed
            checked: SettingsService.showMediaWhenPlaying
            onToggled: function(val) {
                SettingsService.setSetting("showMediaWhenPlaying", val);
            }
        }

        SettingDivider {}

        // 2. Morph to Top Bar When Maximized
        SettingToggle {
            title: "Morph to Top Bar When Windows Maximized"
            description: "Liquidly flattens the island into a full-width GNOME-style top bar"
            iconName: "window"
            iconColor: Theme.accentBlue
            checked: SettingsService.morphToTopBarWhenMaximized
            onToggled: function(val) {
                SettingsService.setSetting("morphToTopBarWhenMaximized", val);
            }
        }

        SettingDivider {}

        // 2b. Reserve Space When Maximized Sub-Toggle
        SettingToggle {
            title: "Reserve Top Bar Space When Maximized"
            description: "Reserves screen space so maximized windows sit underneath the top bar"
            iconName: "maximize"
            iconColor: Theme.accentCyan
            isSubOption: true
            enabled: SettingsService.morphToTopBarWhenMaximized
            checked: SettingsService.reserveSpaceWhenMaximized
            onToggled: function(val) {
                SettingsService.setSetting("reserveSpaceWhenMaximized", val);
            }
        }

        SettingDivider {}

        // 3. Auto-Hide Island on Fullscreen
        SettingToggle {
            title: "Auto-Hide Island on Fullscreen"
            description: "Collapses and completely hides the Island when games or fullscreen apps are active"
            iconName: "desktop"
            iconColor: Theme.accentBlue
            checked: SettingsService.hideOnFullscreen
            onToggled: function(val) {
                SettingsService.setSetting("hideOnFullscreen", val);
            }
        }

        SettingDivider {}

        // Volume / brightness OSD
        SettingToggle {
            title: "Volume & Brightness OSD"
            description: "Show a level indicator in the island when changed with the system IPC shortcuts"
            iconName: "volume-high"
            iconColor: Theme.accentBlue
            checked: SettingsService.showOsd
            onToggled: function(val) {
                SettingsService.setSetting("showOsd", val);
            }
        }

        SettingDivider {}

        // 4. Auto-Collapse Timeout Segmented Picker
        SettingSegmented {
            title: "Auto-Collapse Inactivity Timeout"
            description: "Duration before expanded island automatically collapses when mouse is idle"
            iconName: "clock"
            iconColor: Theme.accentPurple
            currentValue: SettingsService.autoCollapseTimeout
            options: [
                { "label": "3s", "value": 3000 },
                { "label": "6s", "value": 6000 },
                { "label": "10s", "value": 10000 },
                { "label": "Never", "value": 0 }
            ]
            onSelected: function(val) {
                SettingsService.setSetting("autoCollapseTimeout", val);
            }
        }
    }
}
