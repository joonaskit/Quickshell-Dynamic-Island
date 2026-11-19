pragma Singleton
// Quickshell.Bluetooth's qmldir does not declare its dependency on Quickshell, so qmllint
// cannot resolve its types (BluetoothAdapter, UntypedObjectModel)
// qmllint disable unresolved-type
import ".."
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "bluetoothDevices.js" as BluetoothDevices

Singleton {
    id: root

    // BlueZ reports power and device changes as they happen, so nothing is polled
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool isAvailable: root.adapter !== null
    readonly property bool isEnabled: root.adapter ? root.adapter.enabled : false
    readonly property var pairedDevices: BluetoothDevices.pairedList(Bluetooth.devices.values)
    readonly property var connectedDevices: root.pairedDevices.filter(d => d.isConnected)
    readonly property bool isConnected: root.connectedDevices.length > 0
    readonly property string connectingMac: {
        let d = Bluetooth.devices.values.find(d => d.state === BluetoothDeviceState.Connecting);
        return d ? d.address : "";
    }

    // The settings app the popup's footer opens: KDE's module under KDE, else the
    // first of blueman-manager or overskride found. Empty when there is none; the
    // footer is hidden then.
    property var settingsCommand: CompositorService.isKde ? ["kcmshell6", "kcm_bluetooth"] : []
    readonly property bool hasSettings: root.settingsCommand.length > 0

    Process {
        running: !CompositorService.isKde
        command: ["sh", "-c", "for c in \"$@\"; do command -v \"${c%% *}\" >/dev/null 2>&1 && { echo \"$c\"; exit 0; }; done", "sh", "blueman-manager", "overskride"]
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim();
                if (found !== "") root.settingsCommand = found.split(" ");
            }
        }
    }

    function device(mac) {
        return Bluetooth.devices.values.find(d => d.address === mac) || null;
    }

    function togglePower() {
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
    }

    function toggleConnection(mac, isCurrentlyConnected) {
        let d = root.device(mac);
        if (!d) return;
        if (isCurrentlyConnected) d.disconnect();
        else d.connect();
    }

    function openSettings() {
        if (root.hasSettings) Quickshell.execDetached(root.settingsCommand);
    }
}
