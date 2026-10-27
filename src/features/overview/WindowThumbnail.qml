pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

Surface {
    id: root
    required property HyprlandToplevel window
    property Item keyOwner: null
    Keys.forwardTo: root.keyOwner ? [root.keyOwner] : []
    property bool selected: false
    property bool matched: true
    property bool captureEnabled: false
    property Item dragSpace: keyOwner
    property string _gestureAddress: ""
    property bool _dragConsumed: false
    signal dragBegan(string address, point position)
    signal dragMoved(string address, point position)
    signal dragFinished(string address, point position, bool cancelled)
    function scenePoint(point) { return dragSpace ? dragSpace.mapFromItem(null, point.x, point.y) : Qt.point(0,0) }
    function finishGesture(point, cancelled) {
        const address = _gestureAddress
        _gestureAddress = ""
        if (address) root.dragFinished(address, scenePoint(point), cancelled)
    }
    Component.onDestruction: if (_gestureAddress) root.finishGesture(drag?.centroid.scenePosition ?? Qt.point(0,0), true)
    signal selectedRequested(string address)
    signal activated(string address)
    signal moveRequested(string address)
    radius: Tokens.shape.extraSmall
    color: Theme.surfaceContainerHighest
    outlineWidth: selected ? Tokens.focusRing.width : 0
    outlineColor: Theme.primary
    opacity: matched ? 1 : Tokens.state.disabledContentOpacity
    activeFocusOnTab: (matched && selected) || activeFocus
    Accessible.role: Accessible.Button
    Accessible.name: window?.title ?? "Window"
    Accessible.description: "Enter to focus; Ctrl+M to move"
    Accessible.onPressAction: if (window) root.activated(window.address)
    onActiveFocusChanged: if (activeFocus && window) root.selectedRequested(window.address)
    Keys.onPressed: event => {
        const key = Keycodes.key(event)
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            if (!event.isAutoRepeat && root.window) root.activated(root.window.address)
        } else if (key === Qt.Key_Menu || (key === Qt.Key_M && (event.modifiers & Qt.ControlModifier))) {
            if (!event.isAutoRepeat && root.window) root.moveRequested(root.window.address)
        } else return
        event.accepted = true
    }
    Item {
        anchors.fill: parent
        anchors.margins: Tokens.focusRing.width
        clip: true
        Loader {
            id: preview
            objectName: "overviewCaptureLoader"
            anchors.fill: parent
            active: AppConfig.overviewShowPreviews && root.captureEnabled && root.matched && root.window?.wayland !== null && root.window?.wayland !== undefined
            sourceComponent: ScreencopyView {
                objectName: "overviewWindowCapture"
                anchors.centerIn: parent
                captureSource: root.window?.wayland ?? null
                live: true
                constraintSize: Qt.size(Math.max(1,parent.width),Math.max(1,parent.height))
                visible: hasContent
            }
        }
        MaterialIcon {
            anchors.centerIn: parent
            visible: !((preview.item as ScreencopyView)?.hasContent ?? false) && parent.height - (captionSurface.visible ? captionSurface.height : 0) >= Tokens.iconSize.small
            iconName: IconCategoryResolver.getAppCategoryIcon(root.window?.lastIpcObject.class ?? "")
            fontSize: Math.min(Tokens.iconSize.extraLarge, Math.max(0,parent.height - (captionSurface.visible ? captionSurface.height : 0)))
            anchors.verticalCenterOffset: captionSurface.visible ? -captionSurface.height / 2 : 0
        }
    }
    Surface {
        id: captionSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.focusRing.width
        height: caption.implicitHeight + Tokens.spacing.extraSmall
        visible: root.selected || pointer.containsMouse || !((preview.item as ScreencopyView)?.hasContent ?? false)
        color: Qt.alpha(Theme.surfaceContainer, 0.9)
        radius: Tokens.shape.extraSmall
        outlined: false
        MaterialText {
            id: caption
            anchors.fill: parent
            anchors.margins: Tokens.spacing.extraSmall / 2
            text: root.window?.title ?? ""
            textFormat: Text.PlainText
            textStyle: "labelSmall"
            elide: Text.ElideRight
        }
    }
    StateLayer { hovered: pointer.containsMouse && root.matched; focused: root.selected }
    DragHandler {
        id: drag
        target: null
        enabled: root.matched && root.window !== null && root.dragSpace !== null
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onActiveChanged: if (active) {
            root.forceActiveFocus(Qt.MouseFocusReason)
            root._dragConsumed = true
            root._gestureAddress = root.window?.address ?? ""
            if (root._gestureAddress) root.dragBegan(root._gestureAddress,root.scenePoint(centroid.scenePosition))
        }
        onCentroidChanged: if (active && root._gestureAddress) root.dragMoved(root._gestureAddress,root.scenePoint(centroid.scenePosition))
        onGrabChanged: (transition, point) => {
            if (transition === PointerDevice.CancelGrabExclusive) root.finishGesture(point.scenePosition,true)
            else if (transition === PointerDevice.UngrabExclusive) root.finishGesture(point.scenePosition,point.state !== EventPoint.Released)
        }
        onCanceled: point => root.finishGesture(point.scenePosition,true)
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.matched ? Qt.OpenHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root._dragConsumed = false
        onClicked: event => {
            if (root._dragConsumed) return
            if (!root.window || !root.matched) return
            if (event.button === Qt.RightButton) root.moveRequested(root.window.address)
            else root.activated(root.window.address)
        }
    }
}
