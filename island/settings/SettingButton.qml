import "../.."
import QtQuick
import QtQuick.Layouts

// A rounded text button for actions on a settings page
Rectangle {
    id: button

    property string text: ""
    property bool busy: false
    signal clicked()

    Layout.preferredHeight: Theme.px(26)
    Layout.preferredWidth: buttonLabel.implicitWidth + Theme.px(24)
    radius: Theme.px(13)
    color: buttonMouse.containsMouse && !button.busy ? Theme.accentTint(0.3) : Theme.overlay(0.08)
    opacity: button.busy ? 0.4 : 1.0
    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

    Text {
        id: buttonLabel
        anchors.centerIn: parent
        text: button.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        font.weight: Font.Medium
        color: Theme.textPrimary
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!button.busy) button.clicked()
    }
}
