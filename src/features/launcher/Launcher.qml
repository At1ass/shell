import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services

Scope {
    property var modelData

    PanelWindow {
        id: launcherWindow
        visible: GlobalStates.launcherOpen

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
        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Theme.scrim
            opacity: GlobalStates.launcherOpen ? 0.32 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

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
                implicitWidth: AppConfig.launcherWidth
                implicitHeight: launcherContent.implicitHeight

                // MD3 entrance animation (slide down + fade in)
                opacity: GlobalStates.launcherOpen ? 1.0 : 0.0
                y: GlobalStates.launcherOpen ? 0 : -20

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                        easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.emphasizedDecelerate
                        easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
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
                    screen: launcherWindow.screen
                }
            }
        }
    }
}
