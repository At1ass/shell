import QtQuick
import qs.config

Rectangle {
    id: root

    property Item target: parent
    property color layerColor: GreeterTheme.onSurface
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool dragged: false

    anchors.fill: target
    radius: target.radius !== undefined ? target.radius : 0

    color: layerColor
    opacity: {
        if (dragged) return Tokens.stateLayer.draggedOpacity
        if (pressed) return Tokens.stateLayer.pressedOpacity
        if (focused) return Tokens.stateLayer.focusOpacity
        if (hovered) return Tokens.stateLayer.hoverOpacity
        return 0.0
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }
}
