// Turns a key press into the text niri's config uses for a bind, such as "Mod+Shift+T".
// niri names keys by their XKB keysym, ignoring case, and matches the key's unshifted
// symbol: Shift+1 is "Shift+1", not "Shift+exclam". Qt gives the shifted symbol, so the
// number row is read from its scan code, and other shifted symbols are mapped back as on
// a US layout. Super is written "Mod", as in niri's own config.

.pragma library

const META = 0x10000000;
const ALT = 0x08000000;
const CTRL = 0x04000000;
const SHIFT = 0x02000000;

const SPECIAL = {
    0x01000000: "Escape", 0x01000001: "Tab", 0x01000002: "Tab", 0x01000003: "BackSpace",
    0x01000004: "Return", 0x01000005: "KP_Enter", 0x01000006: "Insert", 0x01000007: "Delete",
    0x01000008: "Pause", 0x01000009: "Print", 0x01000010: "Home", 0x01000011: "End",
    0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down",
    0x01000016: "Page_Up", 0x01000017: "Page_Down", 0x01000055: "Menu",
    0x01000070: "XF86AudioLowerVolume", 0x01000071: "XF86AudioMute", 0x01000072: "XF86AudioRaiseVolume",
    0x01000080: "XF86AudioPlay", 0x01000081: "XF86AudioStop", 0x01000082: "XF86AudioPrev",
    0x01000083: "XF86AudioNext", 0x01000085: "XF86AudioPause", 0x01000086: "XF86AudioPlay",
    0x010000b2: "XF86MonBrightnessUp", 0x010000b3: "XF86MonBrightnessDown",
    0x01000113: "XF86AudioMicMute", 0x01000061: "XF86Calculator",
    0x20: "Space"
};

// Printable keys by Qt key code (Latin-1), as XKB names them
const PRINTABLE = {
    0x21: "exclam", 0x22: "quotedbl", 0x23: "numbersign", 0x24: "dollar", 0x25: "percent",
    0x26: "ampersand", 0x27: "Apostrophe", 0x28: "parenleft", 0x29: "parenright",
    0x2A: "asterisk", 0x2B: "plus", 0x2C: "Comma", 0x2D: "Minus", 0x2E: "Period", 0x2F: "Slash",
    0x3A: "colon", 0x3B: "Semicolon", 0x3C: "less", 0x3D: "Equal", 0x3E: "greater",
    0x3F: "question", 0x40: "at", 0x5B: "BracketLeft", 0x5C: "Backslash", 0x5D: "BracketRight",
    0x5E: "asciicircum", 0x5F: "underscore", 0x60: "Grave", 0x7B: "braceleft", 0x7C: "bar",
    0x7D: "braceright", 0x7E: "asciitilde",
    0xA7: "section", 0xA8: "diaeresis", 0xB4: "acute", 0xBD: "onehalf",
    0xC4: "Adiaeresis", 0xC5: "Aring", 0xC6: "AE", 0xD6: "Odiaeresis", 0xD8: "Ooblique",
    0xDC: "Udiaeresis", 0xDF: "ssharp"
};

// What Shift gives on a US layout, back to the key it is on
const US_SHIFTED = {
    0x21: 0x31, 0x40: 0x32, 0x23: 0x33, 0x24: 0x34, 0x25: 0x35, 0x5E: 0x36, 0x26: 0x37,
    0x2A: 0x38, 0x28: 0x39, 0x29: 0x30, 0x5F: 0x2D, 0x2B: 0x3D, 0x7B: 0x5B, 0x7D: 0x5D,
    0x3A: 0x3B, 0x22: 0x27, 0x7E: 0x60, 0x7C: 0x5C, 0x3C: 0x2C, 0x3E: 0x2E, 0x3F: 0x2F
};

// XKB key codes (evdev + 8) of the number row, 1 to 0
const NUMBER_ROW_FIRST = 10;
const NUMBER_ROW_LAST = 19;

function isModifierKey(key) {
    return key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R
        || key === Qt.Key_Shift || key === Qt.Key_Control || key === Qt.Key_Alt
        || key === Qt.Key_AltGr || key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R;
}

// Qt's modifier flags as the bits above
function modifierBits(modifiers) {
    let bits = 0;
    if (modifiers & Qt.MetaModifier) bits |= META;
    if (modifiers & Qt.AltModifier) bits |= ALT;
    if (modifiers & Qt.ControlModifier) bits |= CTRL;
    if (modifiers & Qt.ShiftModifier) bits |= SHIFT;
    return bits;
}

// The key's own name, or "" when niri has no name for it
function keyName(key, mods, scanCode) {
    if (SPECIAL[key] !== undefined) return SPECIAL[key];
    if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1);
    if (mods & SHIFT) {
        if (scanCode >= NUMBER_ROW_FIRST && scanCode <= NUMBER_ROW_LAST)
            return String((scanCode - NUMBER_ROW_FIRST + 1) % 10);
        if (US_SHIFTED[key] !== undefined) key = US_SHIFTED[key];
    }
    if ((key >= 0x30 && key <= 0x39) || (key >= 0x41 && key <= 0x5A)) return String.fromCharCode(key);
    if (PRINTABLE[key] !== undefined) return PRINTABLE[key];
    return "";
}

// { text, error }: the bind text, or why the press cannot be a shortcut
function bindText(key, modifiers, scanCode) {
    let mods = modifierBits(modifiers);
    let name = keyName(key, mods, scanCode);
    if (name === "") return { text: "", error: "niri has no name for that key" };
    let printable = key < 0x01000000;
    if (printable && !(mods & (META | ALT | CTRL)))
        return { text: "", error: "Add Super, Ctrl or Alt" };
    let parts = [];
    if (mods & META) parts.push("Mod");
    if (mods & CTRL) parts.push("Ctrl");
    if (mods & ALT) parts.push("Alt");
    if (mods & SHIFT) parts.push("Shift");
    parts.push(name);
    return { text: parts.join("+"), error: "" };
}
