import QtQuick
import QtTest
import "../services/niriKeys.js" as NiriKeys

TestCase {
    name: "NiriKeys"

    function test_letterWithSuper() {
        compare(NiriKeys.bindText(Qt.Key_T, Qt.MetaModifier, 28), { text: "Mod+T", error: "" });
    }

    function test_modifierOrder() {
        let mods = Qt.ShiftModifier | Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier;
        compare(NiriKeys.bindText(Qt.Key_Left, mods, 113).text, "Mod+Ctrl+Alt+Shift+Left");
    }

    function test_plainLetterRefused() {
        verify(NiriKeys.bindText(Qt.Key_A, Qt.NoModifier, 38).error !== "");
        verify(NiriKeys.bindText(Qt.Key_A, Qt.ShiftModifier, 38).error !== "");
    }

    function test_specialKeysAlone() {
        compare(NiriKeys.bindText(Qt.Key_Print, Qt.NoModifier, 107).text, "Print");
        compare(NiriKeys.bindText(Qt.Key_F5, Qt.NoModifier, 71).text, "F5");
        compare(NiriKeys.bindText(Qt.Key_VolumeUp, Qt.NoModifier, 123).text, "XF86AudioRaiseVolume");
        compare(NiriKeys.bindText(Qt.Key_PageDown, Qt.MetaModifier, 117).text, "Mod+Page_Down");
    }

    function test_shiftedNumberRowUsesScanCode() {
        // Shift+1 reaches Qt as "!" on a US layout and Shift+2 as '"' on a Finnish one
        compare(NiriKeys.bindText(Qt.Key_Exclam, Qt.MetaModifier | Qt.ShiftModifier, 10).text, "Mod+Shift+1");
        compare(NiriKeys.bindText(Qt.Key_QuoteDbl, Qt.MetaModifier | Qt.ShiftModifier, 11).text, "Mod+Shift+2");
        compare(NiriKeys.bindText(Qt.Key_Equal, Qt.MetaModifier | Qt.ShiftModifier, 19).text, "Mod+Shift+0");
    }

    function test_shiftedSymbolMappedBack() {
        compare(NiriKeys.bindText(Qt.Key_Question, Qt.MetaModifier | Qt.ShiftModifier, 61).text, "Mod+Shift+Slash");
    }

    function test_punctuation() {
        compare(NiriKeys.bindText(Qt.Key_Minus, Qt.MetaModifier, 20).text, "Mod+Minus");
        compare(NiriKeys.bindText(Qt.Key_BracketLeft, Qt.MetaModifier, 34).text, "Mod+BracketLeft");
        compare(NiriKeys.bindText(Qt.Key_Adiaeresis, Qt.MetaModifier, 48).text, "Mod+Adiaeresis");
    }

    function test_unknownKey() {
        verify(NiriKeys.bindText(0x01100000, Qt.MetaModifier, 0).error !== "");
    }

    function test_modifierKeys() {
        verify(NiriKeys.isModifierKey(Qt.Key_Meta));
        verify(NiriKeys.isModifierKey(Qt.Key_Shift));
        verify(!NiriKeys.isModifierKey(Qt.Key_A));
    }
}
