pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

// KDE Night Light (KWin). State comes from KWin's D-Bus interface; changes are
// written to kwinrc. KWin does not pick up changes written from outside System
// Settings (a reconfigure does nothing for Night Light), so the Night Light plugin
// is reloaded to apply them. The reload is not saved anywhere.
// Does nothing until the widget is turned on in the settings.
Singleton {
    id: root

    readonly property bool widgetEnabled: SettingsService.nightLightEnabled

    property bool available: true
    // Night Light switched on in KWin (it may still be waiting for the evening)
    property bool active: false
    // Currently tinting the screen
    property bool running: false
    property bool daylight: true
    property int currentTemperature: 6500
    // Night temperature from kwinrc, in kelvin
    property int nightTemperature: 4500
    // kwinrc mode name: DarkLight (sunset to sunrise) or Constant (all day)
    property string mode: "DarkLight"
    // Failed state reads in a row; it is normal for a moment while the plugin reloads
    property int failures: 0
    // True once KWin's state has been read, so a schedule never acts on the defaults
    property bool loaded: false
    // A config write and plugin reload is under way; state read meanwhile may be stale
    property bool busy: false

    // Custom hours: the shell, not KWin, decides when the tint starts and ends. KWin is
    // kept in Constant mode and switched on and off at those times.
    readonly property bool custom: SettingsService.nightLightCustom
    readonly property string scheduleStart: SettingsService.nightLightStart
    readonly property string scheduleEnd: SettingsService.nightLightEnd
    property date now: new Date()
    readonly property bool inWindow: {
        let n = root.now.getHours() * 60 + root.now.getMinutes();
        let from = root.minutesOf(root.scheduleStart);
        let to = root.minutesOf(root.scheduleEnd);
        if (from === to) return false;
        return from < to ? (n >= from && n < to) : (n >= from || n < to);
    }
    // What the on/off button shows: the schedule's switch in custom hours, KWin's otherwise
    readonly property bool switchedOn: root.custom ? SettingsService.nightLightScheduleEnabled : root.active
    // Mode highlighted in the popup
    readonly property string shownMode: root.custom ? "Custom" : root.mode

    function minutesOf(hhmm) {
        let parts = hhmm.split(":");
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    readonly property int minTemperature: 1000
    readonly property int maxTemperature: 6500

    function refresh() {
        if (!stateProc.running) stateProc.running = true;
        if (!configProc.running) configProc.running = true;
    }

    Timer {
        interval: 10000
        running: root.widgetEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: stateProc
        command: ["busctl", "--user", "--json=short", "call", "org.kde.KWin", "/org/kde/KWin/NightLight",
                  "org.freedesktop.DBus.Properties", "GetAll", "s", "org.kde.KWin.NightLight"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let props = JSON.parse(text.trim()).data[0];
                    root.failures = 0;
                    root.available = props.available.data;
                    root.loaded = true;
                    if (!root.busy) root.active = props.enabled.data;
                    root.running = props.running.data;
                    root.daylight = props.daylight.data;
                    root.currentTemperature = props.currentTemperature.data;
                } catch (e) {
                    root.failures++;
                    if (root.failures >= 2) root.available = false;
                }
            }
        }
    }

    // Night temperature and mode live in kwinrc only
    Process {
        id: configProc
        command: ["sh", "-c",
                  "kreadconfig6 --file kwinrc --group NightColor --key NightTemperature --default 4500; " +
                  "kreadconfig6 --file kwinrc --group NightColor --key Mode --default DarkLight"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let temp = parseInt(lines[0]);
                if (!isNaN(temp)) root.nightTemperature = temp;
                if (lines[1] && !root.busy) root.mode = lines[1].trim() === "Constant" ? "Constant" : "DarkLight";
            }
        }
    }

    // Gives the reloaded plugin a moment to appear on D-Bus before reading it again
    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: {
            root.busy = false;
            root.refresh();
        }
    }

    // Checks the clock every 30 s while custom hours are in use
    Timer {
        interval: 30000
        running: root.widgetEnabled && root.custom
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            root.applySchedule();
        }
    }

    // Switches KWin to match the schedule; does nothing while a change is still being applied
    function applySchedule() {
        if (!root.custom || !root.loaded || root.busy) return;
        let wantTint = SettingsService.nightLightScheduleEnabled && root.inWindow;
        if (wantTint !== root.active) {
            root.active = wantTint;
            root.writeConfig({ "Active": wantTint ? "true" : "false" });
        }
    }

    // Changing the hours or the schedule's switch takes effect straight away
    Connections {
        target: SettingsService
        function onSettingsChanged() {
            root.now = new Date();
            root.applySchedule();
        }
    }

    Component {
        id: runner
        Process {
            onExited: {
                refreshTimer.restart();
                destroy(100);
            }
        }
    }

    // Writes keys into kwinrc's NightColor group, then reloads the plugin so KWin reads them.
    // Reloading also ends any preview. A removed plugin leaves the screen at whatever
    // temperature it last set, so when the tint is meant to end the screen is first
    // eased back to the day temperature and the plugin reloaded once that is reached.
    function writeConfig(entries, ease) {
        let willBeActive = entries.Active !== undefined ? entries.Active === "true" : root.active;
        if (ease === undefined) ease = !willBeActive;
        root.busy = true;
        let nl = "org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight";
        let cmd = "";
        for (let key in entries) {
            cmd += "kwriteconfig6 --file kwinrc --group NightColor --key " + key + " " + entries[key] + "; ";
        }
        if (ease) {
            cmd += "busctl --user call " + nl + " preview u " + root.maxTemperature + "; " +
                   "for i in $(seq 25); do " +
                   "t=$(busctl --user get-property " + nl + " currentTemperature); " +
                   "[ \"${t#u }\" -ge " + root.maxTemperature + " ] 2>/dev/null && break; sleep 0.3; done; ";
        }
        cmd += "qdbus-qt6 org.kde.KWin /Plugins org.kde.KWin.Plugins.UnloadPlugin nightlight; " +
               "qdbus-qt6 org.kde.KWin /Plugins org.kde.KWin.Plugins.LoadPlugin nightlight";
        runner.createObject(root, { "command": ["sh", "-c", cmd], "running": true });
    }

    function setActive(on) {
        if (root.custom) {
            SettingsService.setSetting("nightLightScheduleEnabled", on);
            return;
        }
        root.active = on;
        root.writeConfig({ "Active": on ? "true" : "false" }, !on);
    }

    // "DarkLight" follows sunset and sunrise, "Constant" keeps the tint on all day,
    // "Custom" uses the hours chosen here
    function setMode(name) {
        if (name === "Custom") {
            if (root.custom) return;
            // Hold the schedule check until the write below is queued
            root.busy = true;
            SettingsService.setSetting("nightLightScheduleEnabled", root.active);
            SettingsService.setSetting("nightLightCustom", true);
            root.now = new Date();
            let tint = SettingsService.nightLightScheduleEnabled && root.inWindow;
            root.active = tint;
            root.writeConfig({ "Mode": "Constant", "Active": tint ? "true" : "false" });
            return;
        }
        let wasCustom = root.custom;
        SettingsService.setSetting("nightLightCustom", false);
        root.mode = name;
        let entries = { "Mode": name };
        // Leaving custom hours keeps the switch where the user left it
        if (wasCustom) {
            root.active = SettingsService.nightLightScheduleEnabled;
            entries.Active = root.active ? "true" : "false";
        }
        root.writeConfig(entries, name !== "Constant" || (wasCustom && !root.active));
    }

    // Start or end of the custom hours as "HH:MM"; anything else is ignored
    function setScheduleTime(which, text) {
        let m = /^(\d{1,2}):(\d{2})$/.exec(text.trim());
        if (!m || parseInt(m[1]) > 23 || parseInt(m[2]) > 59) return false;
        let value = (m[1].length === 1 ? "0" : "") + m[1] + ":" + m[2];
        SettingsService.setSetting(which === "start" ? "nightLightStart" : "nightLightEnd", value);
        return true;
    }

    // Shows the temperature right away while the slider moves, without saving it
    function previewTemperature(kelvin) {
        root.nightTemperature = Math.round(kelvin);
        previewTimer.restart();
    }

    Timer {
        id: previewTimer
        interval: 60
        onTriggered: Quickshell.execDetached(["busctl", "--user", "call", "org.kde.KWin", "/org/kde/KWin/NightLight",
                                              "org.kde.KWin.NightLight", "preview", "u", String(root.nightTemperature)])
    }

    function commitTemperature(kelvin) {
        previewTimer.stop();
        root.nightTemperature = Math.round(kelvin);
        root.writeConfig({ "NightTemperature": root.nightTemperature });
    }
}
