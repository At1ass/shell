import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.services

PanelWindow {
    id: root

    required property ShellScreen screen

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    color: "transparent"
    visible: PopoutsState.open && PopoutsState.screenName !== screen.name

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:popouts:scrim:" + (screen?.name || "unknown")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: PopoutsState.closePopout()
    }
}
