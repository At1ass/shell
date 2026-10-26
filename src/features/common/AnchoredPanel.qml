pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config

PanelWindow {
    id: root
    property Item anchorItem: null
    property int preferredWidth: Tokens.size.fieldWidth * 2
    property int maxContentHeight: Tokens.size.fieldWidth * 2
    property string panelNamespace: "quickshell:panel"
    property Component panelComponent
    signal closeRequested()

    readonly property ShellScreen targetScreen: root.screen as ShellScreen
    property bool grabReady: false
    function invoke(item, method) { if (item && typeof item[method] === "function") item[method]() }
    function prepare() {
        root.grabReady = false
        grabDelay.stop()
        if (!root.visible) return
        root.invoke(content.item, "reset")
        grabDelay.start()
    }
    Component.onCompleted: if (visible) root.prepare()
    onVisibleChanged: {
        if (visible) root.prepare()
        else { root.grabReady = false; grabDelay.stop() }
    }
    color: "transparent"
    exclusiveZone: 0
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.namespace: root.panelNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    Timer {
        id: grabDelay
        interval: Tokens.interaction.popupGrabDelay
        onTriggered: {
            root.grabReady = true
            root.invoke(content.item, "focusInitial")
        }
    }
    HyprlandFocusGrab {
        active: root.visible && root.grabReady && content.status === Loader.Ready
        windows: [root]
        onCleared: root.closeRequested()
    }
    mask: Region { item: content }
    Loader {
        id: content
        sourceComponent: root.panelComponent
        onLoaded: if (root.visible) root.prepare()
        width: Math.max(0, Math.min(root.preferredWidth, root.width - Tokens.spacing.small * 2))
        height: Math.max(0, Math.min(implicitHeight, root.maxContentHeight,
            root.height - BarMetrics.reservation - Tokens.spacing.small * 2))
        x: {
            const source = root.anchorItem
            if (!source) return Math.max(Tokens.spacing.small, root.width - width - Tokens.spacing.small)
            const pos = source.mapToItem(null, 0, 0)
            const globalX = pos.x + (source.Window.window?.x ?? 0)
            const localX = globalX - (root.targetScreen?.x ?? 0)
            return Math.max(Tokens.spacing.small, Math.min(root.width - width - Tokens.spacing.small, localX + source.width / 2 - width / 2))
        }
        y: AppConfig.barPosition === "bottom"
            ? Math.max(Tokens.spacing.small, root.height - BarMetrics.reservation - height - Tokens.spacing.small)
            : BarMetrics.reservation + Tokens.spacing.small
    }
}
