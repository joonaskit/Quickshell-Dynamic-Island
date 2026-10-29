import QtQuick
import QtTest
import "../services/audioDevices.js" as AudioDevices

TestCase {
    name: "AudioDevices"

    function node(description, nickname, properties) {
        return { "name": "alsa_output.test", "description": description, "nickname": nickname || "", "properties": properties || {} };
    }

    function test_sinkNameFromBrackets() {
        compare(AudioDevices.sinkDisplayName(node("Bluetooth [WH-1000XM4]", "WH-1000XM4 nick")), "WH-1000XM4");
    }

    function test_sinkNameFromNickname() {
        compare(AudioDevices.sinkDisplayName(node("Ryzen HD Audio Controller Analog Stereo", "ALC294 Analog")), "ALC294 Analog");
    }

    function test_sinkNameSkipsDigitalNickname() {
        compare(AudioDevices.sinkDisplayName(node("Built-in Audio Digital Stereo (IEC958)", "ALC897 Digital")), "Digital Output (S/PDIF)");
        compare(AudioDevices.sinkDisplayName(node("Built-in Audio Analog Stereo", "")), "Line Out / Speakers");
    }

    function test_sinkNameFallsBackToName() {
        compare(AudioDevices.sinkDisplayName({ "name": "null-sink" }), "null-sink");
    }

    function test_sinkIcon() {
        compare(AudioDevices.sinkIcon(node("Speakers", "", { "device.icon-name": "audio-card-analog" })), "volume-high");
        compare(AudioDevices.sinkIcon(node("Speakers", "", { "device.form-factor": "headphone" })), "headphones");
        compare(AudioDevices.sinkIcon(node("Pixel Buds", "", { "device.icon-name": "audio-headset-bluetooth" })), "headphones");
        compare(AudioDevices.sinkIcon(node("AirPods Pro", "")), "headphones");
    }

    function test_sourceName() {
        compare(AudioDevices.sourceDisplayName(node("Built-in Audio Analog Stereo", "ALC294 Analog")), "Internal / Analog Mic");
        compare(AudioDevices.sourceDisplayName(node("USB Mic", "Yeti")), "Yeti");
        compare(AudioDevices.sourceDisplayName(node("Headset [Jabra]", "")), "Jabra");
        compare(AudioDevices.sourceDisplayName(node("USB Mic", "")), "USB Mic");
    }

    function test_deviceListMarksDefault() {
        let a = { "name": "a", "description": "A" };
        let b = { "name": "b", "description": "B" };
        let list = AudioDevices.deviceList([a, b], b, AudioDevices.sinkDisplayName);
        compare(list.map(d => d.isDefault), [false, true]);
        compare(list[0].displayName, "A");
        compare(AudioDevices.deviceList([a], null, AudioDevices.sinkDisplayName)[0].isDefault, false);
    }
}
