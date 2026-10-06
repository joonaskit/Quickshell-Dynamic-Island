pragma Singleton
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Countdown timer. Times are absolute timestamps so pauses and UI reloads stay accurate.
    property int timerDuration: 0          // ms, last started duration
    property bool timerRunning: false
    property bool timerPaused: false
    property bool timerFinished: false
    property real timerEndTime: 0          // ms epoch while running
    property real timerPausedRemaining: 0  // ms while paused

    // Stopwatch
    property bool stopwatchRunning: false
    property real stopwatchStartTime: 0    // ms epoch while running
    property real stopwatchAccumulated: 0  // ms from previous runs

    // Updated by the tick timer so bindings re-evaluate
    property real now: Date.now()

    readonly property real timerRemaining: {
        if (root.timerFinished) return 0;
        if (root.timerRunning) return Math.max(0, root.timerEndTime - root.now);
        if (root.timerPaused) return root.timerPausedRemaining;
        return root.timerDuration;
    }
    readonly property real timerProgress: root.timerDuration > 0 ? (root.timerRemaining / root.timerDuration) : 0
    readonly property bool timerActive: root.timerRunning || root.timerPaused || root.timerFinished

    readonly property real stopwatchElapsed: root.stopwatchRunning
        ? root.stopwatchAccumulated + (root.now - root.stopwatchStartTime)
        : root.stopwatchAccumulated
    readonly property bool stopwatchActive: root.stopwatchRunning || root.stopwatchAccumulated > 0

    // What the compact pill should show: "timer", "stopwatch" or ""
    readonly property string pillMode: {
        if (!SettingsService.showTimerInPill) return "";
        if (root.timerActive) return "timer";
        if (root.stopwatchRunning) return "stopwatch";
        return "";
    }

    Timer {
        id: tick
        interval: 100
        repeat: true
        running: root.timerRunning || root.stopwatchRunning
        onTriggered: {
            root.now = Date.now();
            if (root.timerRunning && root.now >= root.timerEndTime) root.finishTimer();
        }
    }

    // Clears the finished state if the user ignores it
    Timer {
        id: finishedTimer
        interval: 30000
        onTriggered: root.resetTimer()
    }

    Process {
        id: notifyProc
    }

    Process {
        id: soundProc
        command: ["sh", "-c", "canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true"]
    }

    function formatTime(ms, showTenths) {
        let total = Math.max(0, Math.floor(ms / 1000));
        let h = Math.floor(total / 3600);
        let m = Math.floor((total % 3600) / 60);
        let s = total % 60;
        let mm = String(m).padStart(2, "0");
        let ss = String(s).padStart(2, "0");
        let base = h > 0 ? (h + ":" + mm + ":" + ss) : (mm + ":" + ss);
        if (showTenths) base += "." + Math.floor((ms % 1000) / 100);
        return base;
    }

    // ---- Timer ----
    function startTimer(ms) {
        if (ms <= 0) return;
        finishedTimer.stop();
        root.now = Date.now();
        root.timerDuration = ms;
        root.timerFinished = false;
        root.timerPaused = false;
        root.timerEndTime = root.now + ms;
        root.timerRunning = true;
    }

    function pauseTimer() {
        if (!root.timerRunning) return;
        root.now = Date.now();
        root.timerPausedRemaining = Math.max(0, root.timerEndTime - root.now);
        root.timerRunning = false;
        root.timerPaused = true;
    }

    function resumeTimer() {
        if (!root.timerPaused) return;
        root.now = Date.now();
        root.timerEndTime = root.now + root.timerPausedRemaining;
        root.timerPaused = false;
        root.timerRunning = true;
    }

    function toggleTimer() {
        if (root.timerRunning) root.pauseTimer();
        else if (root.timerPaused) root.resumeTimer();
        else if (root.timerFinished) root.startTimer(root.timerDuration);
    }

    function resetTimer() {
        finishedTimer.stop();
        root.timerRunning = false;
        root.timerPaused = false;
        root.timerFinished = false;
        root.timerPausedRemaining = 0;
    }

    function finishTimer() {
        root.timerRunning = false;
        root.timerPaused = false;
        root.timerFinished = true;
        finishedTimer.restart();
        notifyProc.command = ["notify-send", "-a", "Island Timer", "-i", "alarm-clock", "Timer finished", root.formatTime(root.timerDuration, false) + " elapsed"];
        notifyProc.running = true;
        soundProc.running = true;
    }

    // ---- Stopwatch ----
    function toggleStopwatch() {
        root.now = Date.now();
        if (root.stopwatchRunning) {
            root.stopwatchAccumulated += root.now - root.stopwatchStartTime;
            root.stopwatchRunning = false;
        } else {
            root.stopwatchStartTime = root.now;
            root.stopwatchRunning = true;
        }
    }

    function resetStopwatch() {
        root.stopwatchRunning = false;
        root.stopwatchAccumulated = 0;
    }
}
