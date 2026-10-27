pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers

PanelWindow {
    id: root
    screen: GlobalStates.activePanelScreen ?? null
    visible: GlobalStates.overviewOpen
    anchors { left:true;right:true;top:true;bottom:true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    property bool grabReady: false
    Timer { id:delay; interval:Tokens.interaction.popupGrabDelay; onTriggered:{root.grabReady=true;content.focusInitial()} }
    HyprlandFocusGrab { active:root.visible && root.grabReady; windows:[root]; onCleared:GlobalStates.closePanel("overview") }
    onVisibleChanged: {
        if (!content) return
        grabReady=false
        if (visible) {content.reset();delay.restart()}
        else delay.stop()
    }
    Component.onCompleted: if (visible) { content.reset();delay.restart() }
    Surface { anchors.fill:parent; radius:0; color:Theme.surface; outlined:false }
    OverviewContent { id:content;anchors.fill:parent }
}
