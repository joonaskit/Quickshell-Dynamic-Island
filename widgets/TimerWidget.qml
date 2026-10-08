import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: parent ? parent.width : Theme.px(370)
    implicitHeight: mainLayout.implicitHeight

    property bool stopwatchTab: false
    // Minutes chosen for the next timer start
    property int selectedMinutes: 5

    readonly property var presets: [1, 5, 10, 15, 30]

    component PillButton: Rectangle {
        id: btn
        property string label: ""
        property string iconName: ""
        property color accent: Theme.textSecondary
        property bool filled: false
        signal clicked()

        Layout.preferredHeight: Theme.px(28)
        Layout.preferredWidth: btnRow.implicitWidth + Theme.px(22)
        radius: height / 2
        color: filled ? Qt.rgba(accent.r, accent.g, accent.b, btnMouse.containsMouse ? 0.34 : 0.24)
                      : (btnMouse.containsMouse ? Theme.overlay(0.12) : Theme.overlay(0.06))
        scale: btnMouse.pressed ? 0.94 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animDurationTooltip; easing.type: Easing.OutCubic } }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: Theme.px(5)

            SvgIcon {
                visible: btn.iconName !== ""
                name: btn.iconName
                size: Theme.px(12)
                color: btn.filled ? btn.accent : Theme.textSecondary
            }

            Text {
                text: btn.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.DemiBold
                color: btn.filled ? btn.accent : Theme.textSecondary
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.px(8)

        // Header with Timer / Stopwatch switch
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(6)

            SvgIcon {
                name: "clock"
                size: Theme.px(13)
                color: Theme.accentOrange
            }

            Text {
                text: "TIMER"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: root.stopwatchTab ? Theme.textTertiary : Theme.textPrimary
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stopwatchTab = false }
            }

            Text {
                text: "STOPWATCH"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                font.weight: Font.DemiBold
                color: root.stopwatchTab ? Theme.textPrimary : Theme.textTertiary
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stopwatchTab = true }
            }

            Item { Layout.fillWidth: true }
        }

        // Big time readout
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.stopwatchTab
                ? TimerService.formatTime(TimerService.stopwatchElapsed, true)
                : (TimerService.timerActive
                    ? (TimerService.timerFinished ? "00:00" : TimerService.formatTime(Math.ceil(TimerService.timerRemaining / 1000) * 1000, false))
                    : TimerService.formatTime(root.selectedMinutes * 60000, false))
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontPx(34)
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: (!root.stopwatchTab && TimerService.timerFinished) ? Theme.accentRed
                 : ((!root.stopwatchTab && TimerService.timerPaused) ? Theme.textSecondary : Theme.textPrimary)
        }

        // Timer presets (only while no timer is active)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.px(6)
            visible: !root.stopwatchTab && !TimerService.timerActive

            PillButton {
                label: "−"
                onClicked: root.selectedMinutes = Math.max(1, root.selectedMinutes - 1)
            }

            Repeater {
                model: root.presets
                delegate: PillButton {
                    required property int modelData
                    label: modelData + "m"
                    filled: root.selectedMinutes === modelData
                    accent: Theme.accentOrange
                    onClicked: root.selectedMinutes = modelData
                }
            }

            PillButton {
                label: "+"
                onClicked: root.selectedMinutes = Math.min(600, root.selectedMinutes + 1)
            }
        }

        // Actions
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.px(8)

            // Timer actions
            PillButton {
                visible: !root.stopwatchTab
                label: TimerService.timerRunning ? "Pause" : (TimerService.timerPaused ? "Resume" : (TimerService.timerFinished ? "Restart" : "Start"))
                iconName: TimerService.timerRunning ? "pause" : "play"
                filled: true
                accent: Theme.accentOrange
                onClicked: {
                    if (TimerService.timerActive) TimerService.toggleTimer();
                    else TimerService.startTimer(root.selectedMinutes * 60000);
                }
            }

            PillButton {
                visible: !root.stopwatchTab && TimerService.timerActive
                label: TimerService.timerFinished ? "Dismiss" : "Cancel"
                iconName: "close"
                onClicked: TimerService.resetTimer()
            }

            // Stopwatch actions
            PillButton {
                visible: root.stopwatchTab
                label: TimerService.stopwatchRunning ? "Stop" : "Start"
                iconName: TimerService.stopwatchRunning ? "pause" : "play"
                filled: true
                accent: Theme.accentBlue
                onClicked: TimerService.toggleStopwatch()
            }

            PillButton {
                visible: root.stopwatchTab && TimerService.stopwatchActive
                label: "Reset"
                iconName: "refresh"
                onClicked: TimerService.resetStopwatch()
            }
        }
    }
}
