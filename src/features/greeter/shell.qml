import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: greeterWindow
            required property ShellScreen modelData

            screen: modelData

            anchors {
                left: true
                top: true
                right: true
                bottom: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "greeter"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0]
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            GreeterSurface {
                anchors.fill: parent
                screen: greeterWindow.modelData
                isPrimary: greeterWindow.modelData === Quickshell.screens[0]
            }
        }
    }
}
