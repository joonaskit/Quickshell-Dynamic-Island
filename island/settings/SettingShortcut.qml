import "../.."
import QtQuick
import QtQuick.Layouts

// Row for one global shortcut: click the key box, then press the new combination
Rectangle {
    id: row
    property string title: ""
    property string description: ""
    property string keysText: ""
    property bool showDivider: true
    property bool capturing: false

    // Qt key code (key plus modifier bits) to bind, or a request to unbind
    signal captured(int code)
    signal cleared()

    readonly property bool matchesSearch: SettingsSearch.matches(title, description + " " + keysText)

    // Bits Qt uses for modifiers in key codes
    readonly property int metaBit: 0x10000000
    readonly property int altBit: 0x08000000
    readonly property int ctrlBit: 0x04000000
    readonly property int shiftBit: 0x02000000

    // Meta pressed on its own may still become the start of a combination
    property bool metaPending: false

    Layout.fillWidth: true
    visible: matchesSearch
    implicitHeight: 52
    color: rowMouse.containsMouse ? Theme.overlay(0.04) : "transparent"
    radius: Theme.corner(10)

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }

    function startCapture() {
        metaPending = false;
        capturing = true;
        captureItem.forceActiveFocus();
    }

    function endCapture() {
        capturing = false;
        metaPending = false;
        captureItem.focus = false;
    }

    function modifierBits(modifiers) {
        let bits = 0;
        if (modifiers & Qt.MetaModifier) bits |= metaBit;
        if (modifiers & Qt.AltModifier) bits |= altBit;
        if (modifiers & Qt.ControlModifier) bits |= ctrlBit;
        if (modifiers & Qt.ShiftModifier) bits |= shiftBit;
        return bits;
    }

    function isMeta(key) {
        return key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R;
    }

    function isModifier(key) {
        return isMeta(key) || key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
            || key === Qt.Key_AltGr || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R;
    }

    function commit(code) {
        endCapture();
        captured(code);
    }

    // Takes keys while the box is waiting for a combination
    Item {
        id: captureItem

        Keys.onPressed: function(event) {
            if (!row.capturing) {
                event.accepted = false;
                return;
            }
            event.accepted = true;
            if (event.isAutoRepeat) return;

            let mods = row.modifierBits(event.modifiers);
            if (event.key === Qt.Key_Escape && mods === 0) {
                row.endCapture();
            } else if (row.isMeta(event.key)) {
                row.metaPending = true;
            } else if (!row.isModifier(event.key)) {
                row.commit(event.key | mods);
            }
        }

        Keys.onReleased: function(event) {
            if (!row.capturing) {
                event.accepted = false;
                return;
            }
            event.accepted = true;
            // Meta released without a second key: bind Meta alone
            if (row.metaPending && row.isMeta(event.key)) {
                row.commit(Qt.Key_Meta);
            }
        }

        onActiveFocusChanged: {
            if (!activeFocus) row.capturing = false;
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (row.capturing) row.endCapture();
            else row.startCapture();
        }
    }

    RowLayout {
        anchors.fill: parent
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
                text: row.description
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textSecondary
                visible: text !== ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Unbind
        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: 10
            visible: row.keysText !== "" && !row.capturing
            color: clearMouse.containsMouse ? Theme.overlay(0.14) : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

            SvgIcon {
                anchors.centerIn: parent
                name: "close"
                size: 11
                color: clearMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.cleared()
            }
        }

        // Current combination, or a prompt while capturing
        Rectangle {
            Layout.preferredWidth: Math.max(86, keyText.implicitWidth + 24)
            Layout.preferredHeight: 26
            radius: Theme.corner(8)
            color: row.capturing ? Theme.accentTint(0.18) : Theme.overlay(0.08)
            border.width: 1
            border.color: row.capturing ? Theme.accent : Theme.overlay(0.08)

            Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.animDurationFast } }

            Text {
                id: keyText
                anchors.centerIn: parent
                text: row.capturing ? "Press keys…" : (row.keysText !== "" ? row.keysText : "None")
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: row.keysText !== "" ? Font.DemiBold : Font.Normal
                color: row.capturing ? Theme.accent : (row.keysText !== "" ? Theme.textPrimary : Theme.textTertiary)
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
