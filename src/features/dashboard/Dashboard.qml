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
        // allowance below applies only to a tab that does not.
        //
        // There used to be a table here as well: `[0, 20, 60, 0, 0]`, a constant
        // per tab indexed by tab NUMBER, added on top of a configured base. Both
        // halves of that go stale on their own schedule -- the pack changes its
        // spacing, a tab grows a row, the font scale moves -- and the result is
        // either a clipped bottom edge or a band of dead space, in a panel whose
        // content was measurable all along. Quick, Weather and Calendar report
        // what they need; Audio and Network are lists that size to whatever they
        // are given, so `dashboard.height` remains their base.
        implicitHeight: _measured > 0
            ? _measured + chromeHeight
            : root.sidebarHeight + (_content?.tabExtraHeight ?? 0)

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
