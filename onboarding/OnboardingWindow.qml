import ".."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The welcome guide: a centred card that walks a new user through a system check,
// importing a configuration, a few starting choices and the basics. Every step can
// be skipped and the window can be closed at any point. State is in OnboardingService.
PanelWindow {
    id: window

    // With no anchors a layer surface sits in the middle of its screen
    screen: ScreenService.primaryScreen

    color: "transparent"
    implicitWidth: Theme.px(680)
    implicitHeight: Theme.px(580)
    exclusionMode: ExclusionMode.Ignore
    visible: OnboardingService.open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-onboarding"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool lastStep: OnboardingService.step === OnboardingService.steps.length - 1

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.corner(22)
        color: Theme.cardBackground
        border.width: 1
        border.color: Theme.overlay(0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.px(22)
            spacing: Theme.px(16)

            // Header: where you are, and a close button
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(6)

                Repeater {
                    model: OnboardingService.steps

                    Rectangle {
                        required property int index
                        implicitWidth: index === OnboardingService.step ? Theme.px(22) : Theme.px(7)
                        implicitHeight: Theme.px(7)
                        radius: height / 2
                        color: index <= OnboardingService.step ? Theme.accent : Theme.overlay(0.16)
                        Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.px(6)
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OnboardingService.goTo(parent.index)
                        }
                    }
                }

                Text {
                    Layout.leftMargin: Theme.px(8)
                    Layout.fillWidth: true
                    text: "Step " + (OnboardingService.step + 1) + " of " + OnboardingService.steps.length + " · " + OnboardingService.steps[OnboardingService.step]
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(11)
                    color: Theme.textTertiary
                }

                Rectangle {
                    Layout.preferredWidth: Theme.px(26)
                    Layout.preferredHeight: Theme.px(26)
                    radius: height / 2
                    color: closeMouse.containsMouse ? Theme.overlay(0.16) : Theme.overlay(0.08)
                    Behavior on color { ColorAnimation { duration: Theme.animDurationFast } }

                    SvgIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.px(12)
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: OnboardingService.close()
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: OnboardingService.step

                OnboardingWelcome {}
                OnboardingSystemCheck {}
                OnboardingImport {}
                OnboardingSetup {}
                OnboardingTips {}
                OnboardingDone {}
            }

            // Footer: leave, go back, go on
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.px(8)

                OnboardingButton {
                    visible: !window.lastStep
                    text: "Skip the guide"
                    onClicked: OnboardingService.close()
                }

                Item { Layout.fillWidth: true }

                OnboardingButton {
                    visible: OnboardingService.step > 0
                    text: "Back"
                    onClicked: OnboardingService.back()
                }

                OnboardingButton {
                    primary: true
                    text: window.lastStep ? "Finish" : (OnboardingService.step === 0 ? "Get started" : "Next")
                    onClicked: OnboardingService.next()
                }
            }
        }
    }
}
