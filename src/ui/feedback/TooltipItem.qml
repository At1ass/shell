import QtQuick
import qs.src.ui.base
import qs.src.core.config

// The QObject owner remains the widget when the visual item moves to the popup.
Item {
    id: root
    required property var tooltip
    required property Item owner
    property string text: ""
    property bool show: false
    property bool targetVisible: false
    property real maximumWidth: tooltip?.maximumWidth ?? Tokens.size.fieldWidth

    property real maximumHeight: tooltip?.maximumHeight ?? Tokens.size.listItem * 8

    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight
    width: implicitWidth
    height: implicitHeight
    visible: false
    opacity: targetVisible ? 1 : 0

    onShowChanged: sync()
    onTooltipChanged: sync()
    Component.onCompleted: sync()
    function sync() {
        if (!tooltip) return
        if (show && owner && text !== "") tooltip.setItem(root)
        else tooltip.removeItem(root)
    }
    onTextChanged: sync()
    onOwnerChanged: sync()

    function reveal(container: Item) {
        parent = container
        visible = true
        targetVisible = true
    }
    function hideImmediately() {
        fade.enabled = false
        targetVisible = false
        visible = false
        parent = null
        fade.enabled = true
    }
    onOpacityChanged: {
        if (!targetVisible && opacity === 0) {
            visible = false
            parent = null
            if (tooltip) tooltip.onHidden(root)
        }
    }
    Behavior on opacity {
        id: fade
        MotionAnimation { duration: Tokens.motion.duration.short2; curve: "standard" }
    }
    MaterialTooltip { id: surface; anchors.fill: parent; text: root.text; maximumWidth: root.maximumWidth; maximumHeight: root.maximumHeight }
}
