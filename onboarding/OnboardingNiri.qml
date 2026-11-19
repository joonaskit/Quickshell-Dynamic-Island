import ".."
import QtQuick
import QtQuick.Layouts
import "../services/desktopConflicts.js" as Conflicts

// The niri step, shown only under niri: the layout a first start set, programs that take
// the island's place (mako, waybar), a key for the launcher and niri-settings.
OnboardingPage {
    id: page

    readonly property bool defaultsApplied: SettingsService.firstStartDefaults.length > 0
    readonly property bool hasNiriSettings: !DepsService.noneUsable(["niri-settings"])
    readonly property var launcherKeys: NiriShortcutService.keysById["shell:launcher.toggle"] || []
    readonly property var conflictRows: {
        let rows = [];
        let c = NotificationService.conflicts;
        if (!c) return rows;
        if (c.notificationOwner) {
            let fix = Conflicts.notificationFix(c.notificationOwner);
            rows.push({ "title": c.notificationOwner + " shows notifications instead of the island", "text": fix.text, "command": fix.command });
        }
        if (c.waybar) {
            let fix = Conflicts.waybarFix(true);
            rows.push({ "title": "waybar is running as a second top bar", "text": fix.text, "command": fix.command });
        }
        return rows;
    }
    // True after the Bind button, until the key list says how it went
    property bool binding: false

    title: "niri"
    intro: "A few things that differ from KDE Plasma."

    onVisibleChanged: {
        if (!visible) return;
        NiriShortcutService.refresh();
        NotificationService.checkConflicts();
    }

    component Heading: Text {
        Layout.fillWidth: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(13)
        font.weight: Font.DemiBold
        color: Theme.textPrimary
    }

    component Body: Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        color: Theme.textSecondary
    }

    // Layout
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(12)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(2)

            Heading { text: "Layout" }

            Body {
                text: page.defaultsApplied
                    ? "The shell started with a layout for niri: the full-width bar, niri's workspaces in the desktops pill and a dock that hides while a window is under it."
                    : "The Top bar settings have a layout for niri: the full-width bar, niri's workspaces in the desktops pill and a dock that hides while a window is under it."
            }
        }

        OnboardingButton {
            text: page.defaultsApplied ? "Change" : "Use it"
            onClicked: {
                if (page.defaultsApplied) SettingsService.requestOpenSettings("Top bar", "niri");
                else SettingsService.applyNiriDefaults();
            }
        }
    }

    // Notifications and a second bar
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.px(6)

        Heading { text: "Notifications" }

        Body {
            visible: page.conflictRows.length === 0
            text: NotificationService.conflicts ? "The island shows notifications, and no other top bar is running." : "Checking…"
        }

        Repeater {
            model: page.conflictRows

            ColumnLayout {
                id: conflictRow
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.px(2)

                Text {
                    Layout.fillWidth: true
                    text: conflictRow.modelData.title
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: Theme.accentOrange
                }

                Body { text: conflictRow.modelData.text }

                RowLayout {
                    visible: conflictRow.modelData.command !== ""
                    Layout.fillWidth: true
                    spacing: Theme.px(12)

                    Text {
                        Layout.fillWidth: true
                        text: conflictRow.modelData.command
                        elide: Text.ElideMiddle
                        font.family: "monospace"
                        font.pixelSize: Theme.fontPx(10)
                        color: Theme.textTertiary
                    }

                    OnboardingButton {
                        text: OnboardingService.copied === conflictRow.modelData.command ? "Copied" : "Copy"
                        onClicked: OnboardingService.copy(conflictRow.modelData.command)
                    }
                }
            }
        }
    }

    // A key for the launcher
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(12)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(2)

            Heading { text: "Launcher key" }

            Body {
                text: page.launcherKeys.length > 0
                    ? "The launcher opens with " + page.launcherKeys.join(" or ") + ". The Shortcuts page in Settings changes it."
                    : (page.binding && NiriShortcutService.error !== ""
                        ? NiriShortcutService.error
                        : "niri cannot open the launcher on Super alone. Bind Mod+Space to it in niri's config?")
            }
        }

        OnboardingButton {
            visible: page.launcherKeys.length === 0
            primary: true
            text: "Bind Mod+Space"
            onClicked: {
                page.binding = true;
                NiriShortcutService.setKey("shell:launcher.toggle", "", "Mod+Space");
            }
        }
    }

    // niri-settings
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.px(12)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(2)

            Heading { text: "niri's own settings" }

            Body {
                text: page.hasNiriSettings
                    ? "niri-settings edits niri's config: key bindings, outputs, input, layout and window rules."
                    : "niri-settings edits niri's config: key bindings, outputs, input, layout and window rules. It is not installed."
            }
        }

        OnboardingButton {
            text: page.hasNiriSettings ? "Open" : "Get it"
            onClicked: {
                if (page.hasNiriSettings) WindowService.openNiriSettings("");
                else Qt.openUrlExternally("https://github.com/joonaskit/niri-settings");
            }
        }
    }
}
