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
    visible: PopoutsState.open

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell:popouts:scrim:" + (screen?.name || "unknown")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
            if (PopoutsState.screenName !== screen.name) {
                mouse.accepted = false
                return
            }
            const x = mouse.x
            const y = mouse.y
            const w = PopoutsState.popoutWidth
            const h = PopoutsState.popoutHeight
            if (w > 0 && h > 0) {
                const inside = x >= PopoutsState.popoutX &&
                    y >= PopoutsState.popoutY &&
                    x <= PopoutsState.popoutX + w &&
                    y <= PopoutsState.popoutY + h
                if (inside) {
                    mouse.accepted = false
                    return
                }
            } else {
                mouse.accepted = false
                return
            }
            if (!PopoutsState.screenName) {
                mouse.accepted = false
                return
            }
            mouse.accepted = true
            PopoutsState.closePopout()
        }
    }
}
