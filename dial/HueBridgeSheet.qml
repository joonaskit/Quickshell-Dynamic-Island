import ".."
import QtQuick

// The Hue page's sheet: pairs with a bridge, or forgets the paired one
DialSheet {
    id: root

    icon: "bulb"
    tint: Theme.accentOrangeStrong
    title: HueService.paired ? "Hue Bridge" : "Connect to Hue"
    status: {
        if (HueService.error !== "") return HueService.error;
        if (HueService.paired) return "Paired with the bridge at " + SettingsService.hueBridgeIp;
        if (HueService.pairState === "waiting") return "Press the round link button on the bridge, then pair again.";
        if (HueService.foundBridges.length > 1) return "Found " + HueService.foundBridges.join(", ") + ". Enter the one to use.";
        return "Enter the bridge address, then press its link button and pair.";
    }
    statusColor: HueService.error !== "" ? Theme.accentRed
        : (!HueService.paired && HueService.pairState === "waiting" ? Theme.accentOrangeStrong : Theme.textSecondary)
    focusItem: HueService.paired ? null : address

    function pair() {
        HueService.setBridge(address.text);
        HueService.pair();
    }

    // Once paired from here, the lamps are on the page
    Connections {
        target: HueService
        function onPairedChanged() {
            if (HueService.paired) root.pageRequested("hue");
        }
    }

    DialField {
        id: address
        visible: !HueService.paired
        tint: root.tint
        placeholder: "Bridge address, e.g. 192.168.1.20"
        text: SettingsService.hueBridgeIp
        onEditingFinished: HueService.setBridge(text)
        onAccepted: root.pair()
        onEscaped: root.closeRequested()
    }

    buttons: [
        DialButton {
            visible: !HueService.paired
            text: HueService.discovering ? "Looking…" : "Find Bridge"
            tint: root.tint
            busy: HueService.discovering
            onClicked: HueService.discover()
        },
        DialButton {
            visible: !HueService.paired
            text: HueService.pairState === "busy" ? "Pairing…" : "Pair"
            tint: root.tint
            primary: true
            busy: HueService.pairState === "busy"
            onClicked: root.pair()
        },
        DialButton {
            visible: HueService.paired
            text: "Forget Bridge"
            tint: Theme.accentRed
            onClicked: HueService.unpair()
        },
        DialButton {
            visible: HueService.paired
            text: "Done"
            tint: root.tint
            primary: true
            onClicked: root.closeRequested()
        }
    ]
}
