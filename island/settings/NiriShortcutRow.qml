import "../.."
import QtQuick
import QtQuick.Layouts
import "../../services/niriKeys.js" as NiriKeys

// Row for one niri action and its keys: click a key to change it, its cross to remove
// it, or + to add another. While waiting for keys the settings window stops niri from
// taking them (NiriShortcutService.capturing).
Rectangle {
    id: row
    property string title: ""
    property string detail: ""
    property var keys: []
    property bool showDivider: true

    // Key being replaced while capturing, "" when adding one
    property string capturingKey: ""
    property bool capturing: false
    // Why the last press was not taken, shown in the box until the next one
    property string hint: ""

    // A combination to bind, in place of `oldKey` ("" adds it), or one to unbind
    signal captured(string oldKey, string newKey)
    signal removed(string key)

    readonly property bool matchesSearch: SettingsSearch.matches(title, detail + " " + keys.join(" "))

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: Math.max(52, content.implicitHeight + 16)
    color: rowMouse.containsMouse ? Theme.overlay(0.04) : "transparent"
    radius: Theme.corner(10)

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }

    function startCapture(key) {
        capturingKey = key;
        hint = "";
        capturing = true;
        NiriShortcutService.capturing = true;
        captureItem.forceActiveFocus();
    }

    function endCapture() {
        if (!capturing) return;
        capturing = false;
        hint = "";
        NiriShortcutService.capturing = false;
        captureItem.focus = false;
    }

    // Takes keys while a box is waiting for a combination
    Item {
        id: captureItem

        Keys.onPressed: function(event) {
            if (!row.capturing) {
                event.accepted = false;
                return;
            }
            event.accepted = true;
            if (event.isAutoRepeat || NiriKeys.isModifierKey(event.key)) return;
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                row.endCapture();
                return;
            }
            let result = NiriKeys.bindText(event.key, event.modifiers, event.nativeScanCode);
            if (result.error !== "") {
                row.hint = result.error;
                return;
            }
            let old = row.capturingKey;
            row.endCapture();
            if (result.text !== old) row.captured(old, result.text);
        }

        onActiveFocusChanged: {
            if (!activeFocus) row.endCapture();
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // One key box: a bound key, the add button, or the prompt while capturing
    component KeyBox: Rectangle {
        id: box
        property string key: ""
        property bool adding: false
        readonly property bool waiting: row.capturing && row.capturingKey === key && (adding || key !== "")
        readonly property string label: waiting ? (row.hint !== "" ? row.hint : "Press keys…") : (adding ? "+" : key)

        width: Math.max(adding && !waiting ? 26 : 56, boxText.implicitWidth + (removeBtn.visible ? 34 : 20))
        height: 26
        radius: Theme.corner(8)
        color: waiting ? Theme.accentTint(0.18) : (boxMouse.containsMouse ? Theme.overlay(0.14) : Theme.overlay(0.08))
        border.width: 1
        border.color: waiting ? Theme.accent : Theme.overlay(0.08)

        Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animDurationFast } }

        MouseArea {
            id: boxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (box.waiting) row.endCapture();
                else row.startCapture(box.adding ? "" : box.key);
            }
        }

        Text {
            id: boxText
            anchors.verticalCenter: parent.verticalCenter
            x: removeBtn.visible ? 10 : (parent.width - width) / 2
            text: box.label
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: box.waiting || box.adding ? Font.Normal : Font.DemiBold
            color: box.waiting ? (row.hint !== "" ? Theme.accentRed : Theme.accent)
                : (box.adding ? Theme.textSecondary : Theme.textPrimary)
        }

        // Unbind, shown on hover
        Rectangle {
            id: removeBtn
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            visible: !box.adding && !box.waiting && (boxMouse.containsMouse || removeMouse.containsMouse)
            color: removeMouse.containsMouse ? Theme.overlay(0.18) : "transparent"

            SvgIcon {
                anchors.centerIn: parent
                name: "close"
                size: 10
                color: removeMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
            }

            MouseArea {
                id: removeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.removed(box.key)
            }
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: row.title
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: row.detail
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
                visible: text !== ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Flow {
            id: keyFlow
            Layout.preferredWidth: Math.min(implicitWidthWanted, row.width * 0.55)
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            layoutDirection: Qt.RightToLeft
            spacing: 6

            // Width the boxes need on one line
            readonly property real implicitWidthWanted: {
                let w = 0;
                for (let i = 0; i < children.length; i++) {
                    if (children[i].visible && children[i].width > 0) w += children[i].width + spacing;
                }
                return Math.max(0, w - spacing);
            }

            // Laid out right to left, so the add button comes first
            KeyBox {
                adding: true
            }

            Repeater {
                model: row.keys.slice().reverse()

                KeyBox {
                    required property string modelData
                    key: modelData
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        visible: row.showDivider && !SettingsSearch.active
        color: Theme.overlay(0.06)
    }
}
