.pragma library

// Paired Bluetooth devices as the Bluetooth popup lists them. Takes plain objects shaped
// like a Quickshell BluetoothDevice ({ address, name, deviceName, paired, connected,
// batteryAvailable, battery }) and
// is kept free of Quickshell types so it can be tested with qmltestrunner (see tests/).

// An icon name for a device, guessed from its name
function iconFor(name) {
    let n = (name || "").toLowerCase();
    if (n.includes("wh-") || n.includes("head") || n.includes("buds") || n.includes("ear") || n.includes("airpod")) return "headphones";
    return "bluetooth";
}

// Paired devices as { mac, name, icon, isConnected, battery }, connected ones first, then
// by name. `battery` is 0 to 1, or -1 when the device does not report it.
function pairedList(devices) {
    let list = (devices || []).filter(d => d && d.paired).map(d => {
        let name = d.name || d.deviceName || d.address;
        return {
            "mac": d.address,
            "name": name,
            "icon": iconFor(name),
            "isConnected": !!d.connected,
            "battery": d.batteryAvailable ? d.battery : -1
        };
    });
    return list.sort((a, b) => {
        if (a.isConnected !== b.isConnected) return a.isConnected ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
}
