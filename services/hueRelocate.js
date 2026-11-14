.pragma library

// When to look for a moved Hue bridge again. Kept free of Quickshell types so it can be
// tested with qmltestrunner (see tests/).

// discovery.meethue.com limits requests
var WAIT_MS = 15 * 60 * 1000;
// A search that never reached the service used up none of that limit, and the network
// may just be back up after a wake
var OFFLINE_WAIT_MS = 60 * 1000;

// msg is the JSON line from `hue.py locate`, or null when there was no readable answer
function waitAfter(msg) {
    return msg && msg.unreachable ? OFFLINE_WAIT_MS : WAIT_MS;
}

// state is "searching", "waiting", "stopped" or ""
function statusText(state, msLeft) {
    if (state === "searching") return "Looking for the bridge...";
    if (state === "stopped") return "Automatic search stopped";
    if (state !== "waiting") return "The bridge may have moved";
    if (msLeft < 60000) return "Searching again in " + Math.ceil(msLeft / 1000) + " s";
    return "Searching again in " + Math.ceil(msLeft / 60000) + " min";
}
