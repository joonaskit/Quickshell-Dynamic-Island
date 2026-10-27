.pragma library

// Matching for the settings window search box. Kept free of Quickshell types so it
// can be tested with qmltestrunner (see tests/).

// Lowercase, without hyphens and underscores, so "auto-hide" finds "autohide" and "Wi-Fi" finds "wifi"
function normalize(text) {
    return String(text || "").toLowerCase().replace(/[-_]/g, "");
}

// Whether every word of the query is somewhere in the text, in any order
function matches(query, text) {
    let words = normalize(query).split(/\s+/).filter(w => w !== "");
    if (words.length === 0) return true;
    let haystack = normalize(text);
    return words.every(w => haystack.indexOf(w) >= 0);
}
