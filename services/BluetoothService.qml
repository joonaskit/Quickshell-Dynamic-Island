pragma Singleton
// Quickshell.Bluetooth's qmldir does not declare its dependency on Quickshell, so qmllint
// cannot resolve its types (BluetoothAdapter, UntypedObjectModel)
// qmllint disable unresolved-type
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

    Process {
        id: settingsProc
        command: ["kcmshell6", "kcm_bluetooth"]
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
        settingsProc.running = true;
    }
}
