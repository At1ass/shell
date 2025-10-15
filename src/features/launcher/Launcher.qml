import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core.services
import qs.src.core.config

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
            color: "#000000"
            opacity: GlobalStates.launcherOpen ? 0.32 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 400  // MD3 normal duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard curve
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
            anchors.topMargin: 56  // 48px бар + 8px MD3 spacing

            sourceComponent: Item {
                implicitWidth: 600
                implicitHeight: launcherContent.implicitHeight

                // MD3 анимация появления (slide down + fade in)
                opacity: GlobalStates.launcherOpen ? 1.0 : 0.0
                y: GlobalStates.launcherOpen ? 0 : -20

                Behavior on opacity {
                    NumberAnimation {
                        duration: 400  // MD3 normal duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]  // MD3 emphasized decelerate
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 400  // MD3 normal duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]  // MD3 emphasized decelerate
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
