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

        // Focus grab для эксклюзивного управления
        HyprlandFocusGrab {
            id: focusGrab
            windows: [launcherWindow]
            active: GlobalStates.launcherOpen

            onCleared: {
                GlobalStates.launcherOpen = false
            }
        }

        // MD3 Scrim (затемнение фона)
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

            // MouseArea для закрытия при кликах на scrim
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.launcherOpen = false
                }
            }
        }

        // Loader для ленивой загрузки контента
        Loader {
            id: contentLoader
            active: GlobalStates.launcherOpen
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: AppConfig.launcherTopMargin  // barHeight + MD3 spacing

            sourceComponent: Item {
                implicitWidth: AppConfig.launcherWidth
                implicitHeight: launcherContent.implicitHeight

                // MD3 анимация появления (slide down + fade in)
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

                // Блокируем клики внутри контента от MouseArea родителя
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Ничего не делаем, просто блокируем прохождение клика
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
