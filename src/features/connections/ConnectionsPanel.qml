pragma ComponentBehavior: Bound
import QtQuick
import qs.src.features.common
import qs.src.core.config
import qs.src.core.services

AnchoredPanel {
    id: root
    screen: GlobalStates.activePanelScreen ?? null
    visible: GlobalStates.connectionsOpen
    anchorItem: GlobalStates.connectionsSource
    preferredWidth: AppConfig.connectionsWidth
    maxContentHeight: AppConfig.connectionsMaxHeight
    panelNamespace: "quickshell:connections"
    onCloseRequested: GlobalStates.closePanel("connections")
    Connections {
        target: GlobalStates
        function onPanelOpened(name) { if (name === "connections") root.prepare() }
    }
    panelComponent: Component {
        ConnectionsContent { onCloseRequested: root.closeRequested() }
    }
}
