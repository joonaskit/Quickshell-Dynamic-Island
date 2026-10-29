.pragma library

// Names and icons for audio devices. Takes plain objects shaped like a PipeWire node
// ({ name, description, nickname, properties }) and is kept free of Quickshell types
// so it can be tested with qmltestrunner (see tests/).

// The text inside the last [...] of a description, e.g. a Bluetooth device's name
function bracketed(desc) {
    let start = desc.lastIndexOf("[");
    let end = desc.lastIndexOf("]");
    return (start !== -1 && end > start) ? desc.slice(start + 1, end) : "";
}

function sinkDisplayName(node) {
    let desc = node.description || node.name || "";
    let nick = node.nickname || "";
    if (bracketed(desc)) return bracketed(desc);
    if (nick && nick !== "ALC897 Digital") return nick;
    if (desc.includes("IEC958")) return "Digital Output (S/PDIF)";
    if (desc.includes("Analog Stereo")) return "Line Out / Speakers";
    return desc;
}

function sinkIcon(node) {
    let p = node.properties || {};
    let fields = [p["device.icon-name"] || p["device.icon_name"] || "",
                  p["device.form-factor"] || p["device.form_factor"] || "",
                  node.description || "", node.name || ""];
    let isHeadphones = fields.some(f => ["head", "ear", "airpod"].some(k => f.toLowerCase().includes(k)));
    return isHeadphones ? "headphones" : "volume-high";
}

function sourceDisplayName(node) {
    let desc = node.description || node.name || "";
    let nick = node.nickname || "";
    if (desc.includes("Analog Stereo")) return "Internal / Analog Mic";
    if (nick) return nick;
    return bracketed(desc) || desc;
}

// Devices as the device lists show them, the default one marked
function deviceList(nodes, defaultNode, displayName) {
    return nodes.map(n => ({
        "name": n.name,
        "description": n.description,
        "displayName": displayName(n),
        "icon": sinkIcon(n),
        "isDefault": defaultNode !== null && n.name === defaultNode.name
    }));
}
