pragma ComponentBehavior: Bound
import QtQuick
import qs.src.features.common
import qs.src.core.config
import qs.src.core.services

AnchoredPanel {
    id: root
    screen: GlobalStates.activePanelScreen ?? null
    visible: GlobalStates.audioOpen
    anchorItem: GlobalStates.audioSource
    preferredWidth: AppConfig.audioWidth
    maxContentHeight: AppConfig.audioMaxHeight
    panelNamespace: "quickshell:audio"
    onCloseRequested: GlobalStates.closePanel("audio")
    Connections {
        target: GlobalStates
        function onPanelOpened(name) { if (name === "audio") root.prepare() }
    }
    panelComponent: Component { AudioContent { onCloseRequested: root.closeRequested() } }
}
