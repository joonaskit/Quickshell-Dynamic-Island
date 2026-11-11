import ".."
import QtQuick

// The KDE Connect page's sheet: sends a text or a link to the chosen device
DialSheet {
    id: root

    readonly property var device: KdeConnectService.device

    icon: "phone"
    tint: Theme.accentGreenStrong
    title: device ? "Send to " + device.name : "Send Text"
    status: device && device.reachable ? "A link opens on the device; other text goes to its clipboard" : "The device is not connected"
    focusItem: message

    // The page's status line shows how the send went
    function send() {
        if (!device || message.text.trim() === "") return;
        KdeConnectService.shareText(device.id, message.text);
        root.closeRequested();
    }

    DialField {
        id: message
        tint: root.tint
        placeholder: "Text or a link"
        onAccepted: root.send()
        onEscaped: root.closeRequested()
    }

    buttons: [
        DialButton {
            text: "Cancel"
            tint: root.tint
            onClicked: root.closeRequested()
        },
        DialButton {
            text: "Send"
            tint: root.tint
            primary: true
            enabled: root.device !== null && root.device.reachable
            onClicked: root.send()
        }
    ]
}
