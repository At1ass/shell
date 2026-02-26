import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services

Scope {
    property var modelData

    PanelWindow {
        id: cheatsheetWindow
        visible: GlobalStates.cheatsheetOpen

        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: focusGrab
            windows: [cheatsheetWindow]
            active: GlobalStates.cheatsheetOpen

            onCleared: {
                GlobalStates.cheatsheetOpen = false
            }
        }

        // MD3 Scrim
        Rectangle {
            id: scrim
            anchors.fill: parent
            color: "#000000"
            opacity: GlobalStates.cheatsheetOpen ? 0.32 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.cheatsheetOpen = false
                }
            }
        }

        // Content loader
        Loader {
            id: contentLoader
            active: GlobalStates.cheatsheetOpen
            anchors.centerIn: parent

            sourceComponent: Item {
                id: contentWrapper
                implicitWidth: 920
                implicitHeight: Math.min(cheatsheetWindow.height - 80, 720)

                // MD3 appear animation (opacity + scale)
                opacity: GlobalStates.cheatsheetOpen ? 1.0 : 0.0
                scale: GlobalStates.cheatsheetOpen ? 1.0 : 0.95

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                        easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                        easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                    }
                }

                // Block click-through
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                CheatsheetContent {
                    id: cheatsheetContent
                    anchors.fill: parent
                }
            }
        }
    }
}
