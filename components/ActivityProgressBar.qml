import ".."
import QtQuick

// A thin progress bar. `progress` is 0..1, or negative when the total is not known.
Rectangle {
    id: root

    property real progress: 0
    property color accent: Theme.accentBlue
    readonly property bool indeterminate: progress < 0

    implicitHeight: Theme.px(4)
    radius: height / 2
    color: Theme.overlay(0.14)
    clip: true

    Rectangle {
        id: fill
        height: parent.height
        radius: height / 2
        color: root.accent
        width: root.indeterminate ? parent.width * 0.3 : parent.width * Math.max(0, Math.min(1, root.progress))
        x: 0

        Behavior on width {
            enabled: !root.indeterminate
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }

        SequentialAnimation on x {
            running: root.indeterminate && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: root.width - fill.width; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { from: root.width - fill.width; to: 0; duration: 900; easing.type: Easing.InOutQuad }
        }
    }
}
