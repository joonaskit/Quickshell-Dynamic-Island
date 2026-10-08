pragma Singleton
import ".."
import QtQuick
import Quickshell

// Widgets shown in the expanded island, in display order. ExpandedView builds
// itself from this list and the settings page generates its toggles from it.
// See docs/WIDGETS.md for the entry fields and the widget interface.
Singleton {
    id: root

    readonly property var widgets: [
        {
            "id": "calendar",
            "title": "Mini Calendar",
            "description": "Monthly calendar grid with current date highlight and week numbers",
            "icon": "calendar",
            "iconColor": Theme.accentRed,
            "group": "cards",
            "defaultEnabled": true,
            "component": calendarComponent
        },
        {
            "id": "timer",
            "title": "Timer & Stopwatch",
            "description": "Countdown timer and stopwatch card",
            "icon": "clock",
            "iconColor": Theme.accentOrange,
            "group": "cards",
            "defaultEnabled": true,
            "component": timerComponent
        },
        {
            "id": "media",
            "title": "Media Player",
            "description": "Playback controls, album artwork, track title, and interactive seek bar",
            "icon": "music",
            "iconColor": Theme.accentRed,
            "group": "cards",
            "defaultEnabled": true,
            "component": mediaComponent,
            "available": function(host) { return host.player !== null; }
        },
        {
            "id": "audioOutput",
            "title": "Audio Output Selector",
            "description": "Quickly switch active audio playback device (speakers, headphones, HDMI)",
            "icon": "headphones",
            "iconColor": Theme.accentBlue,
            "group": "controls",
            "defaultEnabled": true,
            "component": audioOutputComponent
        },
        {
            "id": "appMixer",
            "title": "App Volume Mixer",
            "description": "Per-app volume sliders for apps that are playing audio",
            "icon": "music",
            "iconColor": Theme.accentBlue,
            "group": "controls",
            "defaultEnabled": true,
            "component": appMixerComponent,
            "available": function(host) { return AppMixerService.streams.length > 0; }
        },
        {
            "id": "volume",
            "title": "Volume Slider",
            "description": "Interactive slider for master speaker output volume",
            "icon": "volume-high",
            "iconColor": Theme.accentGreen,
            "group": "controls",
            "defaultEnabled": true,
            "component": volumeComponent
        },
        {
            "id": "brightness",
            "title": "Brightness Slider",
            "description": "Interactive slider for screen backlight brightness",
            "icon": "brightness-high",
            "iconColor": Theme.accentYellow,
            "group": "controls",
            "defaultEnabled": true,
            "component": brightnessComponent,
            "available": function(host) { return BrightnessService.isAvailable; }
        }
    ]

    function byId(id) {
        for (let i = 0; i < widgets.length; i++) {
            if (widgets[i].id === id) return widgets[i];
        }
        return null;
    }

    Component { id: calendarComponent; MiniCalendarWidget {} }
    Component { id: timerComponent; TimerWidget {} }
    Component { id: mediaComponent; MediaWidget {} }
    Component { id: audioOutputComponent; AudioOutputSelector {} }
    Component { id: appMixerComponent; AppVolumeMixer {} }
    Component { id: volumeComponent; VolumeSlider {} }
    Component { id: brightnessComponent; BrightnessSlider {} }
}
