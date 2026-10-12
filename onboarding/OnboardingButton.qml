import ".."
import QtQuick

// Pill button for the welcome guide. `primary` fills it with the accent colour
Rectangle {
    id: button

    property string text: ""
    property bool primary: false
    property bool active: true
    signal clicked()

    implicitHeight: Theme.px(30)
    implicitWidth: label.implicitWidth + Theme.px(28)
    radius: height / 2
    color: {
        if (button.primary) return buttonMouse.containsMouse && button.active ? Qt.lighter(Theme.accent, 1.12) : Theme.accent;
        return buttonMouse.containsMouse && button.active ? Theme.overlay(0.16) : Theme.overlay(0.08);
    }
    opacity: button.active ? 1.0 : 0.4
    scale: buttonMouse.pressed && button.active ? 0.96 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(12)
        font.weight: Font.DemiBold
        color: button.primary ? Theme.accentForeground : Theme.textPrimary
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (button.active) button.clicked()
    }
}
