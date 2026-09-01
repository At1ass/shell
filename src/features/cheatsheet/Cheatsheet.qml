pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
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

        // The output to map onto, resolved by GlobalStates.openPanel once per
        // open and before the open flag flips -- so this window is still
        // invisible when it moves, and a RETAINED panel still lands on the
        // monitor the user is looking at. Resolving in Component.onCompleted
        // was only correct while every open rebuilt the window.
        screen: GlobalStates.activePanelScreen ?? null

        WlrLayershell.namespace: "quickshell:cheatsheet"
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
        // Held active once the panel is retained; see Launcher.qml.
        Loader {
            id: contentLoader
            active: GlobalStates.cheatsheetOpen || GlobalStates.panelRetained("cheatsheet")
            anchors.centerIn: parent

            sourceComponent: Item {
                id: contentWrapper
                implicitWidth: 920
                implicitHeight: Math.min(cheatsheetWindow.height - 80, 720)

                // Created by a Loader with the open flag ALREADY true, so a
                // Behavior never saw a change and this animation was dead — see
                // Scrim._ready. The flag holds the binding at the start value
                // for one pass so the first evaluation is a real transition.
                property bool _ready: false
                Component.onCompleted: contentWrapper._ready = true

                // MD3 appear animation (opacity + scale)
                opacity: contentWrapper._ready && GlobalStates.cheatsheetOpen ? 1.0 : 0.0
                scale: contentWrapper._ready && GlobalStates.cheatsheetOpen ? 1.0 : 0.95

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
