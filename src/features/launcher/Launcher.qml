import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.services

Scope {

    PanelWindow {
        id: launcherWindow
        visible: GlobalStates.launcherOpen

        // Open on the focused monitor (see GlobalStates.focusedScreen).
        Component.onCompleted: {
            const s = GlobalStates.focusedScreen()
            if (s) launcherWindow.screen = s
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

        // Focus grab for exclusive input control
        HyprlandFocusGrab {
            id: focusGrab
            windows: [launcherWindow]
            active: GlobalStates.launcherOpen

            onCleared: {
                GlobalStates.closePanel("launcher")
            }
        }

        // MD3 Scrim (background dimming)
        Scrim {
            id: scrim
            shown: GlobalStates.launcherOpen
            duration: Tokens.motion.duration.medium4

            // MouseArea to close on scrim clicks
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.closePanel("launcher")
                }
            }
        }

        // Loader for lazy content loading
        Loader {
            id: contentLoader
            active: GlobalStates.launcherOpen
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: AppConfig.launcherTopMargin  // barHeight + MD3 spacing

            sourceComponent: Item {
                id: launcherCard
                implicitWidth: AppConfig.launcherWidth
                implicitHeight: launcherContent.implicitHeight

                // Created by a Loader with the open flag ALREADY true, so a
                // Behavior never saw a change and this animation was dead — see
                // Scrim._ready. The flag holds the binding at the start value
                // for one pass so the first evaluation is a real transition.
                property bool _ready: false
                Component.onCompleted: launcherCard._ready = true

                // MD3 entrance animation (slide down + fade in)
                opacity: launcherCard._ready && GlobalStates.launcherOpen ? 1.0 : 0.0
                y: launcherCard._ready && GlobalStates.launcherOpen ? 0 : -20

                Behavior on opacity {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
                    }
                }

                Behavior on y {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium4
                        curve: "emphasizedDecelerate"
                    }
                }

                // Block clicks inside the content from the parent MouseArea
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Do nothing, just block the click from passing through
                    }
                }

                LauncherContent {
                    id: launcherContent
                    anchors.fill: parent
                }
            }
        }
    }
}
