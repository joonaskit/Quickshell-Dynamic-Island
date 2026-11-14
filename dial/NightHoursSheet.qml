import ".."
import QtQuick

// The Night Light page's sheet: the two times of the custom schedule
DialSheet {
    id: root

    icon: "clock"
    tint: Theme.accentOrangeStrong
    title: "Custom Hours"
    status: invalid ? "Times are written as HH:MM, such as 22:00" : "Night Light tints the screen between these times"
    statusColor: invalid ? Theme.accentRed : Theme.textSecondary
    focusItem: from

    property bool invalid: false

    // Saves both times and goes back to the page; a bad time stays for fixing
    function save() {
        let ok = NightLightService.setScheduleTime("start", from.text);
        ok = NightLightService.setScheduleTime("end", to.text) && ok;
        root.invalid = !ok;
        if (ok) root.closeRequested();
    }

    Row {
        width: parent.width
        spacing: Theme.px(8)

        DialField {
            id: from
            width: (parent.width - parent.spacing) / 2
            tint: root.tint
            label: "From"
            inputMask: "99:99"
            text: NightLightService.scheduleStart
            onAccepted: to.takeFocus()
            onEscaped: root.closeRequested()
        }
        DialField {
            id: to
            width: (parent.width - parent.spacing) / 2
            tint: root.tint
            label: "To"
            inputMask: "99:99"
            text: NightLightService.scheduleEnd
            onAccepted: root.save()
            onEscaped: root.closeRequested()
        }
    }

    buttons: [
        DialButton {
            text: "Cancel"
            tint: root.tint
            onClicked: root.closeRequested()
        },
        DialButton {
            text: "Save"
            tint: root.tint
            primary: true
            onClicked: root.save()
        }
    ]
}
