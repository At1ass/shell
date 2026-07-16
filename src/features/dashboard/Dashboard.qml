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

    property int sidebarWidth: AppConfig.dashboardWidth
    property int sidebarHeight: AppConfig.dashboardHeight

    // Extra window height per tab (Weather and Calendar content run taller).
    // Indexed by GlobalStates.dashboardOpenIndex: Quick/Weather/Calendar/Audio/Network.
    readonly property var tabExtraHeight: [0, 20, 60, 0, 0]

    PanelWindow {
        id: dashboardWindow
        color: "transparent"
        implicitWidth: root.sidebarWidth
        implicitHeight: root.sidebarHeight + (root.tabExtraHeight[GlobalStates.dashboardOpenIndex] ?? 0)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.emphasizedDecelerate
                easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
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
                GlobalStates.closePanel("dashboard")
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
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.closePanel("dashboard")
                }
            }
        }
    }
}
