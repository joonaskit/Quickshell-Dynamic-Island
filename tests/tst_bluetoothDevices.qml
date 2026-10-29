import QtQuick
import QtTest
import "../services/bluetoothDevices.js" as BluetoothDevices

TestCase {
    name: "BluetoothDevices"

    function dev(address, name, paired, connected) {
        return { "address": address, "name": name, "deviceName": "", "paired": paired, "connected": connected };
    }

    function test_onlyPairedDevices() {
        let list = BluetoothDevices.pairedList([dev("A", "Mouse", true, false), dev("B", "Phone", false, false)]);
        compare(list.map(d => d.mac), ["A"]);
    }

    function test_connectedFirstThenByName() {
        let list = BluetoothDevices.pairedList([
            dev("A", "Zebra", true, false),
            dev("B", "Keyboard", true, true),
            dev("C", "Apple", true, false)
        ]);
        compare(list.map(d => d.name), ["Keyboard", "Apple", "Zebra"]);
        compare(list.map(d => d.isConnected), [true, false, false]);
    }

    function test_nameFallsBack() {
        compare(BluetoothDevices.pairedList([{ "address": "A", "name": "", "deviceName": "WH-1000XM4", "paired": true }])[0].name, "WH-1000XM4");
        compare(BluetoothDevices.pairedList([{ "address": "AA:BB", "paired": true }])[0].name, "AA:BB");
    }

    function test_noDevices() {
        compare(BluetoothDevices.pairedList([]), []);
        compare(BluetoothDevices.pairedList(null), []);
    }
}
