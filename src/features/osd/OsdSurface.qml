pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

// Passive surfaces keep their output for one presentation. Repeated actions
// choose the currently focused output; pointer movement alone never moves one.
Scope {
    id: root
    property bool shown: false
    property string targetScreenName: ""
    property string namespacePart: "osd"
    property string edge: "top"
    property color cardColor: Theme.surfaceContainerHigh
    property int cardWidth: 0
    property int cardHeight: 0
    property Component contentComponent: null
    readonly property int topEdgeMargin: Tokens.spacing.large
        + (AppConfig.barPosition === "top" ? BarMetrics.reservation : 0)
    readonly property int bottomEdgeMargin: Tokens.spacing.extraLarge
        + (AppConfig.barPosition === "bottom" ? BarMetrics.reservation : 0)

    function present(outputName) {
        let name = outputName ?? ""
        if (!Array.from(Quickshell.screens).some(screen => screen?.name === name))
            name = GlobalStates.focusedScreen()?.name ?? ""
        targetScreenName = name
        shown = true
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: osdWindow
            required property ShellScreen modelData
            screen: modelData
            readonly property bool selectedOutput: modelData !== null && (AppConfig.osdMonitorPolicy === "all"
                || modelData.name === root.targetScreenName)
            readonly property bool presenting: root.shown && selectedOutput && !GlobalStates.lockscreenActive
            visible: !GlobalStates.lockscreenActive && selectedOutput
                && (presenting || osdContent.opacity > 0.01)
            color: "transparent"
            mask: Region {}
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:" + root.namespacePart
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: root.edge === "top"; bottom: root.edge === "bottom" }
            Binding { target: osdWindow; property: "margins.top"; value: root.edge === "top" ? root.topEdgeMargin : 0 }
            Binding { target: osdWindow; property: "margins.bottom"; value: root.edge === "bottom" ? root.bottomEdgeMargin : 0 }
            readonly property int maximumWidth: Math.max(1, (modelData?.width ?? 1) - Tokens.spacing.small * 2)
            readonly property int maximumHeight: Math.max(1, (modelData?.height ?? 1)
                - (root.edge === "top" ? root.topEdgeMargin : root.bottomEdgeMargin) - Tokens.spacing.small)
            implicitWidth: card.width
            implicitHeight: card.height
            Item {
                id: osdContent
                anchors.centerIn: parent
                width: card.width
                height: card.height
                opacity: osdWindow.presenting ? 1 : 0
                Behavior on opacity {
                    enabled: !GlobalStates.lockscreenActive && osdWindow.selectedOutput
                    MotionAnimation { duration: Tokens.motion.duration.short4; curve: "standard" }
                }
                MaterialCard {
                    id: card
                    elevation: 2
                    color: root.cardColor
                    radius: Tokens.shape.large
                    width: Math.max(1, Math.min(osdWindow.maximumWidth,
                        root.cardWidth > 0 ? root.cardWidth : contentLoader.implicitWidth))
                    height: Math.max(1, Math.min(osdWindow.maximumHeight,
                        root.cardHeight > 0 ? root.cardHeight : contentLoader.implicitHeight))
                    Loader { id: contentLoader; anchors.fill: parent; sourceComponent: root.contentComponent }
                }
            }
        }
    }
}
