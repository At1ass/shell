import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.services
import qs.src.core.config

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
        readonly property ShellScreen targetScreen: GlobalStates.activePanelScreen
        readonly property int availableWidth: Math.max(1, (targetScreen?.width ?? root.sidebarWidth) - Tokens.spacing.small * 2)
        readonly property int availableHeight: Math.max(1, (targetScreen?.height ?? root.sidebarHeight) - BarMetrics.reservation - Tokens.spacing.small * 2)
        implicitWidth: Math.min(root.sidebarWidth, availableWidth)
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
        // their measured height. The configured height is only a fallback.
        implicitHeight: Math.min(availableHeight, _measured > 0
            ? _measured + chromeHeight
            : root.sidebarHeight + (_content?.tabExtraHeight ?? 0))

        // Everything the window holds around the tab's own content: the loader's
        // margins and the tab bar above it.
        readonly property int chromeHeight: Tokens.spacing.small * 2 + (_content?.chromeHeight ?? 0)

        // Resize the native surface once to the measured target. Animating this
        // property resizes the entire layout every frame, retargets measurements
        // during lazy loading and competes with the player's own morph.
        property bool _contentReady: false
        on_MeasuredChanged: if (_measured > 0) _contentReady = true
        Component.onCompleted: if (_measured > 0) _contentReady = true
        anchors {
            top: AppConfig.barPosition !== "bottom"
            bottom: AppConfig.barPosition === "bottom"
        }
        Binding { target: dashboardWindow; property: "margins.top"; value: AppConfig.barPosition !== "bottom" ? BarMetrics.reservation + Tokens.spacing.small : 0 }
        Binding { target: dashboardWindow; property: "margins.bottom"; value: AppConfig.barPosition === "bottom" ? BarMetrics.reservation + Tokens.spacing.small : 0 }
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        visible: GlobalStates.dashboardOpen && dashboardWindow._contentReady

        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay

        // Auto-close on click outside the area
        HyprlandFocusGrab {
            id: focusGrab
            active: dashboardWindow.visible && dashboardLoader.active && GlobalStates.dashboardOpen
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
