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
        visible: GlobalStates.controlPanelOpen
        color: "transparent"
        implicitWidth: root.sidebarWidth
        anchors {
            top: true
            right: true
            bottom: true
        }
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell:controlPanel"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {
            item: contentLoader
        }

        // Автозакрытие при клике вне области
        HyprlandFocusGrab {
            id: focusGrab
            active: GlobalStates.controlPanelOpen
            windows: [controlWindow]
            onCleared: () => {
                console.log("ControlPanel focus lost, closing");
                GlobalStates.controlPanelOpen = false;
            }
            onActiveChanged: {
                console.log("HyprlandFocusGrab active changed to:", active, "controlPanelOpen:", GlobalStates.controlPanelOpen);
            }
        }

        // Закрытие по Escape через Item внутри окна
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    console.log("Escape pressed, closing ControlPanel");
                    GlobalStates.controlPanelOpen = false;
                }
            }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            anchors {
                fill: parent
                margins: 10
                rightMargin: 10
            }
            focus: GlobalStates.controlPanelOpen
            active: GlobalStates.controlPanelOpen
            sourceComponent: controlPanelComponent

        }
        // Rectangle {
        //     id: controlBackground
        //     anchors.fill: parent
        //     // height: parent.height
        //     // color: Config.colors.surfaceContainerHigh
        //     color: "black"
        //     border.width: 1
        //     border.color: Config.colors.outlineVariant
        //     // clip: true
        //
        //     // Простая тень слева
        //     // Rectangle {
        //     //     anchors.fill: parent
        //     //     anchors.rightMargin: Config.spacing.small
        //     //     anchors.topMargin: Config.spacing.small
        //     //     color: Qt.alpha("#000000", 0.1)
        //     //     z: -1
        //     // }
        //
        // }
        // }
    }

    Component {
        id: controlPanelComponent
        ControlPanelContent {}
    }
}
