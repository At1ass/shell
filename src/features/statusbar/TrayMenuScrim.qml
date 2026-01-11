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
    visible: GlobalStates.trayMenuOpen && GlobalStates.trayMenuOwner !== screen.name

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:traymenu:scrim:" + (screen?.name || "unknown")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: GlobalStates.closeTrayMenu()
    }
}
