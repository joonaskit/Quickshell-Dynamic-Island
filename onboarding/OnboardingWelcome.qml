import ".."
import QtQuick
import QtQuick.Layouts

OnboardingPage {
    title: "Welcome to Quickshell Island"
    intro: "A short tour of what is on your screen, a check of your system and a few choices to start with. It takes a couple of minutes, and you can skip any step."

    Repeater {
        model: [
            { "icon": "clock", "color": Theme.accentBlue, "title": "The island",
              "text": "The pill at the top of the screen shows the clock, the music that is playing and new notifications. When a window is maximised it stretches into a top bar." },
            { "icon": "grid", "color": Theme.accentPurple, "title": "The expanded view",
              "text": "Hover or click the pill to open it. Inside are the calendar, timer, media controls, notifications, volume and brightness, and the button that opens Settings." },
            { "icon": "sliders", "color": Theme.accentGreen, "title": "The status icons",
              "text": "The icons at the top right show Wi-Fi, Bluetooth, the microphone and more. Click one for its quick settings." },
            { "icon": "apps", "color": Theme.accentOrange, "title": "The dock",
              "text": "Pinned and running apps sit in the dock. Its first button opens the app launcher, which also searches and switches between open windows." }
        ]

        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.px(12)

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Theme.px(34)
                Layout.preferredHeight: Theme.px(34)
                radius: Theme.corner(10)
                color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.18)

                SvgIcon {
                    anchors.centerIn: parent
                    name: modelData.icon
                    size: Theme.px(17)
                    color: modelData.color
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.px(2)

                Text {
                    text: modelData.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.text
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(12)
                    color: Theme.textSecondary
                }
            }
        }
    }
}
