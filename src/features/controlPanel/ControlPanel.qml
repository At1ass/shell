import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.services
import qs.src.core.config

Scope {
    id: root

    property int sidebarWidth: 580

    PanelWindow {
        id: controlWindow
        implicitWidth: root.sidebarWidth
        visible: GlobalStates.controlPanelOpen
        anchors {
            top: true
            right: true
            bottom: true
        }
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.namespace: "quickshell:controlPanel"
        WlrLayershell.layer: WlrLayer.Overlay

        // Автозакрытие при клике вне области
        HyprlandFocusGrab {
            id: focusGrab
            active: GlobalStates.controlPanelOpen
            windows: [controlWindow]
            onCleared: () => {
                console.log("ControlPanel focus lost, closing");
                GlobalStates.controlPanelOpen = false;
                GlobalStates.showDateSelector = false;
            }
            onActiveChanged: {
                console.log("HyprlandFocusGrab active changed to:", active, "controlPanelOpen:", GlobalStates.controlPanelOpen);
            }
        }
        Loader {
            id: controlPanelLoader
            active: GlobalStates.controlPanelOpen

            onActiveChanged: {
                console.log("ControlPanelLoader active changed to:", active);
            }

            anchors {
                fill: parent
                margins: 10
                rightMargin: 10
            }

            focus: GlobalStates.controlPanelOpen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    console.log("Escape pressed, closing ControlPanel");
                    GlobalStates.controlPanelOpen = false;
                    GlobalStates.showDateSelector = false;
                }
            }

            sourceComponent: ControlPanelContent {}
        }
    }
}
