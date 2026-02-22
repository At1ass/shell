import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.services
import qs.src.core.config
import qs.src.ui.containers
import qs.src.ui.base

Scope {
    id: root

    property int sidebarWidth: 900
    property int sidebarHight: 640

    PanelWindow {
        id: dashboardWindow
        color: "transparent"
        implicitWidth: root.sidebarWidth
        implicitHeight: root.sidebarHight

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Tokens.motion.duration.medium2
                easing.type: Tokens.motion.easing.emphasizedDecelerate
            }
        }
        anchors {
            top: true
        }
        exclusiveZone: 0

        visible: GlobalStates.dashboardOpen

        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay

        // Автозакрытие при клике вне области
        HyprlandFocusGrab {
            id: focusGrab
            active: dashboardLoader.active && GlobalStates.dashboardOpen
            windows: [dashboardWindow]
            onCleared: () => {
                console.log("Dashboard: focus lost, closing dashboard")
                GlobalStates.dashboardOpen = false;
            }
        }

        Loader {
            id: dashboardLoader
            active: GlobalStates.dashboardOpen

            focus: GlobalStates.dashboardOpen

            anchors {
                fill: parent
                margins: 10
                leftMargin: 10
            }

            sourceComponent: DashboardContent {
                anchors.fill: parent
                implicitWidth: parent.implicitWidth
                implicitHeight: parent.implicitHeight

                Component.onCompleted: {
                    dashboardWindow.implicitHeight = root.sidebarHight
                }

                onRequestHeightChange: (newHeight) => {
                    dashboardWindow.implicitHeight = newHeight
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.dashboardOpen = false;
                }
            }
        }
    }
}
