import ".."
import QtQuick
import QtQuick.Layouts

// Step 3: bring a configuration from another machine, or carry on with the defaults
OnboardingPage {
    title: "Import or start fresh"
    intro: "If you exported your configuration on another machine, or before a reinstall, you can load it now. Otherwise go on to the next step and start from the defaults."

    Text {
        Layout.fillWidth: true
        text: "An import replaces the settings and the pinned dock apps, and takes effect at once. The files it replaces are copied to a backup folder first. You can also import later, in Settings under About."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(12)
        color: Theme.textSecondary
    }

    OnboardingButton {
        visible: BackupService.pickerAvailable
        text: BackupService.busy ? "Importing…" : "Import a configuration…"
        active: !BackupService.busy
        onClicked: BackupService.pick("import")
    }

    Text {
        visible: !BackupService.pickerAvailable
        Layout.fillWidth: true
        text: "No file dialog (kdialog or zenity) is installed, so import from a terminal instead:\n./run.sh --import <file>"
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(12)
        color: Theme.textSecondary
    }

    Text {
        visible: text !== ""
        Layout.fillWidth: true
        text: BackupService.notice
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        color: BackupService.noticeIsError ? Theme.accentRed : Theme.accentGreen
    }
}
