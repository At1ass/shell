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

    // Height adjustment per tab for the tabs that do NOT measure themselves:
    // Weather and Calendar run taller than the base. Indexed by
    // GlobalStates.dashboardOpenIndex: Quick/Weather/Calendar/Audio/Network.
    //
    // Quick carries a 0 because it reports its own content height instead. It
    // used to carry a constant, and that constant went stale the first time the
    // pack changed its spacing -- a fixed number cannot track content it does
    // not measure.
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
        readonly property DashboardContent _content: dashboardLoader.item as DashboardContent
        readonly property int _measured: _content?.tabContentHeight ?? 0

        // A tab that measures itself already counts its expanded sections --
        // its content height IS the column including them -- so the expansion
        // allowance applies only to the tabs sized from the fixed table.
        implicitHeight: _measured > 0
            ? _measured + chromeHeight
            : root.sidebarHeight
              + (root.tabExtraHeight[GlobalStates.dashboardOpenIndex] ?? 0)
              + (_content?.tabExtraHeight ?? 0)

        // Everything the window holds around the tab's own content: the loader's
        // margins and the tab bar above it.
        readonly property int chromeHeight: Tokens.spacing.small * 2 + (_content?.chromeHeight ?? 0)

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
