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

        // The output to map onto, resolved by GlobalStates.openPanel once per
        // open and before the open flag flips -- so this window is still
        // invisible when it moves, and a RETAINED panel still lands on the
        // monitor the user is looking at. Resolving in Component.onCompleted
        // was only correct while every open rebuilt the window.
        screen: GlobalStates.activePanelScreen ?? null

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

        // Held active once the panel is retained; see Launcher.qml.
        Loader {
            id: dashboardLoader
            active: GlobalStates.dashboardOpen || GlobalStates.panelRetained("dashboard")

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
