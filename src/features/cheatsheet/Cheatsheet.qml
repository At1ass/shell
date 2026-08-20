pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.services

Scope {
    property var modelData

    PanelWindow {
        id: cheatsheetWindow
        visible: GlobalStates.cheatsheetOpen

        // Open on the focused monitor (see GlobalStates.focusedScreen).
        Component.onCompleted: {
            const s = GlobalStates.focusedScreen()
            if (s) cheatsheetWindow.screen = s
        }

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
                GlobalStates.closePanel("cheatsheet")
            }
        }

        // MD3 Scrim
        Scrim {
            id: scrim
            shown: GlobalStates.cheatsheetOpen
            duration: Tokens.motion.duration.medium4

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.closePanel("cheatsheet")
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
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
                    }
                }

                Behavior on scale {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
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
