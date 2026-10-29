.pragma library

// Paired Bluetooth devices as the Bluetooth popup lists them. Takes plain objects shaped
// like a Quickshell BluetoothDevice ({ address, name, deviceName, paired, connected }) and
// is kept free of Quickshell types so it can be tested with qmltestrunner (see tests/).

// Paired devices as { mac, name, isConnected }, connected ones first, then by name
function pairedList(devices) {
    let list = (devices || []).filter(d => d && d.paired).map(d => ({
        "mac": d.address,
        "name": d.name || d.deviceName || d.address,
        "isConnected": !!d.connected
    }));
    return list.sort((a, b) => {
        if (a.isConnected !== b.isConnected) return a.isConnected ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
}
