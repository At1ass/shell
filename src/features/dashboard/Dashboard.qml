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
    readonly property list<int> tabExtraHeight: [0, 20, 60, 0, 0]

    PanelWindow {
        id: dashboardWindow

        // Open on the monitor the user is actually looking at (see
        // GlobalStates.focusedScreen). The LazyLoader in shell.qml rebuilds this
        // window per open, so resolving once at construction is enough.
        Component.onCompleted: {
            const s = GlobalStates.focusedScreen()
            if (s) dashboardWindow.screen = s
        }

        color: "transparent"
        implicitWidth: root.sidebarWidth
        implicitHeight: root.sidebarHeight + (root.tabExtraHeight[GlobalStates.dashboardOpenIndex] ?? 0)

        Behavior on implicitHeight {
            MotionAnimation {
                duration: Tokens.motion.duration.short4
                curve: "emphasizedDecelerate"
            }
        }
        anchors {
            top: true
        }
        exclusiveZone: 0

        visible: GlobalStates.dashboardOpen

        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay

        // Auto-close on click outside the area
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
                margins: Tokens.spacing.small
            }

            // No implicit-size bindings back to the Loader: it forwards its
            // item's implicit size, so those would be circular.
            sourceComponent: DashboardContent {
                anchors.fill: parent
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.closePanel("dashboard")
                }
            }
        }
    }
}
