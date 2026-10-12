import ".."
import QtQuick
import QtQuick.Layouts

OnboardingPage {
    title: "You are set"
    intro: "That is the basics. Everything you chose here, and a great deal more, can be changed in Settings at any time."

    Repeater {
        model: {
            let lines = [];
            let missing = OnboardingService.problems.length;
            if (OnboardingService.report) {
                lines.push(missing === 0 ? "Every tool and service the shell uses was found."
                    : missing + (missing === 1 ? " tool or service is" : " tools or services are") + " still missing. Run ./run.sh --check at any time to see which.");
            }
            lines.push("Settings open from the gear button in the expanded view.");
            lines.push("Optional widgets such as Philips Hue, Night Light, KDE Connect and GameMode are off until you turn them on, in Settings under Widgets.");
            lines.push("This guide can be opened again from Settings under About.");
            return lines;
        }

        RowLayout {
            required property string modelData
            Layout.fillWidth: true
            spacing: Theme.px(10)

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Theme.px(5)
                Layout.preferredWidth: Theme.px(6)
                Layout.preferredHeight: Theme.px(6)
                radius: height / 2
                color: Theme.accent
            }

            Text {
                Layout.fillWidth: true
                text: modelData
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(12)
                color: Theme.textSecondary
            }
        }
    }

    OnboardingButton {
        text: "Open Settings"
        onClicked: {
            OnboardingService.close();
            SettingsService.requestOpenSettings("");
        }
    }
}
