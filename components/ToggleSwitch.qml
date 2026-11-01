import ".."
import QtQuick

// An on / off switch. A row that is clickable as a whole sets `interactive` to false and
// handles the click itself.
Rectangle {
    id: toggle

    property bool checked: false
    property bool interactive: true
    property real trackWidth: Theme.px(46)
    property real trackHeight: Theme.px(26)
    signal clicked()

    property real knobInset: Theme.px(2)
    readonly property real knobSize: trackHeight - 2 * knobInset

    implicitWidth: trackWidth
    implicitHeight: trackHeight
    radius: trackHeight / 2
    color: checked ? Theme.accentGreen : Theme.controlTrackOff

    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

    Rectangle {
        x: toggle.checked ? toggle.trackWidth - toggle.knobSize - toggle.knobInset : toggle.knobInset
        y: toggle.knobInset
        width: toggle.knobSize
        height: toggle.knobSize
        radius: toggle.knobSize / 2
        color: Theme.sliderHandle

        Behavior on x {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: toggle.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }
}
