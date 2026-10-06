import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool isTimer: TimerService.pillMode === "timer"
    readonly property bool finished: root.isTimer && TimerService.timerFinished
    readonly property bool paused: root.isTimer && TimerService.timerPaused
    readonly property color accent: root.finished ? Theme.accentRed : (root.isTimer ? Theme.accentOrange : Theme.accentBlue)

    implicitHeight: Theme.compactHeight
    implicitWidth: Theme.px(150)

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.px(9)

        // Progress ring (timer) or static clock icon (stopwatch)
        Item {
            Layout.preferredWidth: Theme.px(20)
            Layout.preferredHeight: Theme.px(20)

            Canvas {
                id: ring
                anchors.fill: parent
                visible: root.isTimer
                property real progress: TimerService.timerProgress
                property color ringColor: root.accent
                onProgressChanged: requestPaint()
                onRingColorChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let c = width / 2;
                    let r = c - 2;
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16);
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, Math.PI * 2);
                    ctx.stroke();
                    ctx.strokeStyle = ringColor;
                    ctx.beginPath();
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, progress));
                    ctx.stroke();
                }
            }

            SvgIcon {
                anchors.centerIn: parent
                visible: !root.isTimer
                name: "clock"
                size: Theme.px(16)
                color: root.accent
            }
        }

        Text {
            text: root.isTimer
                ? (root.finished ? "Done" : TimerService.formatTime(Math.ceil(TimerService.timerRemaining / 1000) * 1000, false))
                : TimerService.formatTime(TimerService.stopwatchElapsed, true)
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(14)
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: root.finished ? Theme.accentRed : (root.paused ? Theme.textSecondary : Theme.textPrimary)

            // Blink when finished
            SequentialAnimation on opacity {
                running: root.finished
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 450 }
                NumberAnimation { to: 1.0; duration: 450 }
                onRunningChanged: if (!running) parent.opacity = 1.0
            }
        }
    }
}
