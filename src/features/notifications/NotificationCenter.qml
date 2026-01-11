import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.features.notifications

Scope {
    PanelWindow {
        id: centerWindow
        visible: GlobalStates.notificationCenterOpen
        focusable: true
        color: "transparent"

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notification-center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            active: GlobalStates.notificationCenterOpen
            windows: [centerWindow]
            onCleared: GlobalStates.notificationCenterOpen = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                const insidePanel = mouse.x >= panel.x &&
                                    mouse.x <= panel.x + panel.width &&
                                    mouse.y >= panel.y &&
                                    mouse.y <= panel.y + panel.height
                if (!insidePanel) {
                    GlobalStates.notificationCenterOpen = false
                }
            }
        }

        NotificationCenterPanel { z: 1 }
    }
}
