import ".."
import QtQuick

// A button of a DialSheet: a pill, as the pills on the dial's ring. The `primary` one is
// filled with its colour, the others tinted with it.
Rectangle {
    id: root

    property string text: ""
    property color tint: Theme.accentBlue
    property bool primary: false
    // Dimmed and not clickable while its action runs
    property bool busy: false

    signal clicked()

    width: label.implicitWidth + Theme.px(28)
    height: Theme.px(30)
    radius: height / 2
    color: primary ? Qt.alpha(tint, mouse.containsMouse ? 0.85 : 1)
        : (mouse.containsMouse ? Qt.alpha(tint, 0.3) : Theme.overlay(0.08))
    opacity: busy || !enabled ? 0.5 : 1
    scale: mouse.pressed ? 0.95 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "#ffffff" : Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        font.bold: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
