.pragma library

// Reading of settings.json formats older than the current one, used by
// SettingsService.applySettings. Kept free of Quickshell types so it can be
// tested with qmltestrunner (see tests/).

// Per-widget keys used before the "widgets" map
const legacyWidgetKeys = {
    "calendar": "showExpandedCalendar",
    "timer": "showExpandedTimer",
    "media": "showExpandedMedia",
    "audioOutput": "showExpandedAudioSink",
    "appMixer": "showExpandedAppMixer",
    "volume": "showExpandedVolume",
    "brightness": "showExpandedBrightness"
};

// Returns { id: enabled } for the widgets in `widgetIds` that have a saved
// state in `data` (the parsed settings.json). The "widgets" map wins over a
// legacy key; widgets with neither are left out so the registry default applies.
function widgetStates(data, widgetIds) {
    let states = {};
    if (!data || typeof data !== "object") return states;
    let saved = (data.widgets && typeof data.widgets === "object") ? data.widgets : {};
    for (let i = 0; i < widgetIds.length; i++) {
        let id = widgetIds[i];
        let legacyKey = legacyWidgetKeys[id];
        if (saved[id] !== undefined) states[id] = !!saved[id];
        else if (legacyKey && data[legacyKey] !== undefined) states[id] = !!data[legacyKey];
    }
    return states;
}
