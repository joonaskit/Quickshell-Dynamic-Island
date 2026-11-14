import ".."
import QtQuick

// Right-click menu of a dial tile (see DialService.menuFor). The window places it and
// closes it; this only draws the entries and says which one was chosen.
Rectangle {
    id: root

    // [{ name, icon, run, closes }] or { separator: true }
    property var entries: []
    // The highlighted entry, moved by the arrow keys and the pointer; -1 for none
    property int current: -1

    signal chosen(var entry)

    readonly property bool isOpen: entries.length > 0

    // Index of the next entry from `from` in `step` direction, skipping separators
    function nextFrom(from, step) {
        let n = entries.length;
        if (n === 0) return -1;
        let i = from;
        for (let k = 0; k < n; k++) {
            i = (i + step + n) % n;
            if (!entries[i].separator) return i;
        }
        return -1;
    }

    function move(step) {
        current = nextFrom(current < 0 ? (step > 0 ? -1 : 0) : current, step);
    }

    function choose() {
        if (current >= 0 && current < entries.length) chosen(entries[current]);
    }

    width: Theme.px(230)
    height: column.implicitHeight + Theme.px(12)
    radius: Theme.cornerPx(12)
    color: Theme.islandBackground
    border.width: 1
    border.color: Theme.glassHairline
    visible: isOpen

    // Takes the pointer so presses do not reach the disc below
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
    }

    Column {
        id: column
        x: Theme.px(6)
        y: Theme.px(6)
        width: parent.width - Theme.px(12)

        Repeater {
            model: root.entries

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: column.width
                height: modelData.separator ? Theme.px(9) : Theme.px(32)

                Rectangle {
                    visible: row.modelData.separator === true
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.px(8)
                    width: parent.width - Theme.px(16)
                    height: 1
                    color: Theme.glassHairline
                }

                Rectangle {
                    visible: !row.modelData.separator
                    anchors.fill: parent
                    radius: Theme.cornerPx(8)
                    color: row.index === root.current ? Qt.alpha(Theme.accentBlue, 0.24) : "transparent"

                    SvgIcon {
                        x: Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon || "chevron-right"
                        size: Theme.px(14)
                        color: Theme.textPrimary
                    }

                    Text {
                        x: Theme.px(34)
                        width: parent.width - x - Theme.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.name || ""
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(12)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = row.index
                        onClicked: root.chosen(row.modelData)
                    }
                }
            }
        }
    }
}
