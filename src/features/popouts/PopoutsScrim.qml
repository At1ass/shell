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
            console.log("PopoutsScrim: mouse pressed")
            console.log("PopoutsScrim: screen", screen.name, "popoutScreen", PopoutsState.screenName)
            if (PopoutsState.screenName !== screen.name) {
                console.log("PopoutsScrim: non-owner screen, ignoring click")
                mouse.accepted = false
                return
            }
            if (PopoutsState.screenName === screen.name) {
                const x = mouse.x
                const y = mouse.y
                const w = PopoutsState.popoutWidth
                const h = PopoutsState.popoutHeight
                if (w > 0 && h > 0) {
                    const inside = x >= PopoutsState.popoutX &&
                        y >= PopoutsState.popoutY &&
                        x <= PopoutsState.popoutX + w &&
                        y <= PopoutsState.popoutY + h
                    console.log("PopoutsScrim: click", screen.name, "x", x, "y", y,
                                "rect", PopoutsState.popoutX, PopoutsState.popoutY,
                                w, h, "inside", inside)
                    if (inside) {
                        console.log("PopoutsScrim: click inside popout bounds, ignoring")
                        mouse.accepted = false
                        return
                    }
                } else {
                    console.log("PopoutsScrim: rect not ready, ignoring click",
                                "screen", screen.name, "rect", PopoutsState.popoutX,
                                PopoutsState.popoutY, w, h)
                    mouse.accepted = false
                    return
                }
            }
            if (!PopoutsState.screenName) {
                console.log("PopoutsScrim: popout screen not set, ignoring click")
                mouse.accepted = false
                return
            }
            console.log("PopoutsScrim: closing popout due to outside click")
            mouse.accepted = true
            PopoutsState.closePopout()
        }
    }
}
