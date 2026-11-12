pragma Singleton
import QtQuick
import Quickshell

// Which compositor the shell runs under. KDE-only helpers (the KWin window tracker,
// Night Light) are started only under KWin; elsewhere the services fall back to the
// generic Wayland protocols. ISLAND_COMPOSITOR overrides the guess.
Singleton {
    id: root

    // "kde", "niri" or "other"
    readonly property string name: {
        let forced = (Quickshell.env("ISLAND_COMPOSITOR") || "").toLowerCase();
        if (forced === "kde" || forced === "niri" || forced === "other") return forced;
        // Before XDG_CURRENT_DESKTOP: niri started from inside Plasma keeps Plasma's value
        if (Quickshell.env("NIRI_SOCKET")) return "niri";
        let desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toUpperCase().split(":");
        return desktop.indexOf("KDE") >= 0 ? "kde" : "other";
    }

    readonly property bool isKde: name === "kde"
    readonly property bool isNiri: name === "niri"
}
