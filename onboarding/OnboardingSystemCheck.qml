import ".."
import QtQuick
import QtQuick.Layouts

// Step 2: what scripts/check_deps.py found, in plain language. Nothing is
// installed from here; the command is only shown, to copy into a terminal.
OnboardingPage {
    id: page

    readonly property var report: OnboardingService.report
    property bool showOptional: false

    title: "System check"
    intro: {
        if (!page.report) return OnboardingService.checkFailed ? "The check could not run. Try ./run.sh --check in a terminal." : "Checking the tools and services the shell uses…";
        let total = page.report.dependencies.length;
        let missing = OnboardingService.problems.length;
        if (missing === 0) return "All " + total + " tools and services the shell uses were found. Nothing to do here.";
        return (total - missing) + " of " + total + " tools and services were found. The features below will not work until the rest are installed.";
    }

    // One dependency that was not found. Inline components cannot see this file's ids
    component ProblemRow: RowLayout {
        id: row

        property var dep: ({ "name": "", "severity": "", "status": "", "features": [], "note": "" })
        readonly property color tagColor: dep.severity === "required" ? Theme.accentRed : (dep.severity === "recommended" ? Theme.accentOrange : Theme.textTertiary)

        Layout.fillWidth: true
        spacing: Theme.px(10)

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Theme.px(5)
            Layout.preferredWidth: Theme.px(7)
            Layout.preferredHeight: Theme.px(7)
            radius: height / 2
            color: row.tagColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.px(1)

            Text {
                Layout.fillWidth: true
                text: row.dep.name + (row.dep.status === "not-running" ? " · installed, but not running" : (row.dep.severity === "required" ? " · required" : ""))
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                text: row.dep.features.join(" · ")
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                color: Theme.textSecondary
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: row.dep.note
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10)
                color: Theme.textTertiary
            }
        }
    }

    Repeater {
        model: OnboardingService.importantProblems

        ProblemRow {
            required property var modelData
            dep: modelData
        }
    }

    // Optional ones only cost a single feature, so they stay folded away until asked for
    OnboardingButton {
        visible: OnboardingService.optionalProblems.length > 0
        text: (page.showOptional ? "Hide " : "Show ") + OnboardingService.optionalProblems.length + " optional"
        onClicked: page.showOptional = !page.showOptional
    }

    Repeater {
        model: page.showOptional ? OnboardingService.optionalProblems : []

        ProblemRow {
            required property var modelData
            dep: modelData
        }
    }

    // The command that installs what is missing, to copy
    Rectangle {
        visible: page.report !== null && page.report.installCommand !== ""
        Layout.fillWidth: true
        implicitHeight: commandColumn.implicitHeight + Theme.px(20)
        radius: Theme.corner(12)
        color: Theme.overlay(0.05)
        border.width: 1
        border.color: Theme.overlay(0.08)

        ColumnLayout {
            id: commandColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.px(10)
            spacing: Theme.px(8)

            Text {
                text: "Run this in a terminal to install them, then check again:"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                color: Theme.textSecondary
            }

            Text {
                Layout.fillWidth: true
                text: page.report ? page.report.installCommand : ""
                wrapMode: Text.WrapAnywhere
                font.family: "monospace"
                font.pixelSize: Theme.fontPx(11)
                color: Theme.textPrimary
            }

            OnboardingButton {
                readonly property string command: page.report ? page.report.installCommand : ""
                text: OnboardingService.copied !== "" && OnboardingService.copied === command ? "Copied" : "Copy command"
                onClicked: OnboardingService.copy(command)
            }
        }
    }

    Text {
        visible: page.report !== null && OnboardingService.problems.length > 0 && page.report.installCommand === "" && page.report.distro === ""
        Layout.fillWidth: true
        text: "Package names are only known for Arch, Fedora, openSUSE and Debian or Ubuntu. Look for the tools above in your distribution's packages."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontPx(11)
        color: Theme.textSecondary
    }

    OnboardingButton {
        text: OnboardingService.checking ? "Checking…" : "Check again"
        active: !OnboardingService.checking
        onClicked: OnboardingService.runCheck()
    }
}
