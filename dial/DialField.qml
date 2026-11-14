import ".."
import QtQuick

// A text field of a DialSheet: a pill with a hairline, as the dial's password field.
// Enter emits `accepted`, Esc `escaped`.
Rectangle {
    id: root

    property alias text: input.text
    property alias inputMask: input.inputMask
    property alias echoMode: input.echoMode
    property string placeholder: ""
    // A short label inside the left end ("From"), or ""
    property string label: ""
    property color tint: Theme.accentBlue

    signal accepted()
    signal escaped()
    signal editingFinished()

    function takeFocus() {
        input.forceActiveFocus();
    }

    width: parent ? parent.width : Theme.px(260)
    height: Theme.px(34)
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: input.activeFocus ? Qt.alpha(root.tint, 0.7) : Theme.glassHairline
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: labelText
        x: Theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.label !== ""
        text: root.label
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(10)
        font.bold: true
    }

    TextInput {
        id: input
        anchors.centerIn: parent
        width: parent.width - Theme.px(32) - (labelText.visible ? 2 * labelText.width : 0)
        horizontalAlignment: TextInput.AlignHCenter
        color: Theme.textPrimary
        selectionColor: Qt.alpha(root.tint, 0.5)
        selectedTextColor: Theme.textPrimary
        selectByMouse: true
        clip: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(14)

        onAccepted: root.accepted()
        onEditingFinished: root.editingFinished()
        Keys.onEscapePressed: root.escaped()

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            visible: input.text === "" && input.inputMask === ""
            text: root.placeholder
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: input.font.pixelSize
            font.weight: Font.Light
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
    }
}
