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
                duration: Config.motion.duration.medium2
                easing.type: Config.motion.easing.emphasizedDecelerate
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
                console.log("Dashboard focus lost, closing");
                GlobalStates.dashboardOpen = false;
            }
            onActiveChanged: {
                console.log("HyprlandFocusGrab active changed to:", active, "dashboardOpen:", GlobalStates.dashboardOpen);
            }
        }

        Loader {
            id: dashboardLoader
            active: GlobalStates.dashboardOpen

            focus: GlobalStates.dashboardOpen

            onActiveChanged: {
                console.log("DashboardContentLoader active changed to:", active);
            }

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
                    console.log("DashboardContent loaded");
                    // Изначально устанавливаем высоту окна
                    dashboardWindow.implicitHeight = root.sidebarHight
                }

                onRequestHeightChange: (newHeight) => {
                    dashboardWindow.implicitHeight = newHeight
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    console.log("Escape pressed, closing Dashboard");
                    GlobalStates.dashboardOpen = false;
                }
            }
        }
    }
}
