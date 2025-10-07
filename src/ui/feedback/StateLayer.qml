import QtQuick
import qs.src.core.config

// Material Design 3 State Layer
// Universal overlay component for hover/pressed/focus feedback
Rectangle {
    id: root

    // Properties
    property Item target: parent
    property color layerColor: Config.colors.onSurface
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool dragged: false

    // Positioning
    anchors.fill: target
    radius: target.radius !== undefined ? target.radius : 0

    // Color and opacity
    color: layerColor
    opacity: {
        if (dragged) return Config.stateLayer.draggedOpacity
        if (pressed) return Config.stateLayer.pressedOpacity
        if (focused) return Config.stateLayer.focusOpacity
        if (hovered) return Config.stateLayer.hoverOpacity
        return 0.0
    }

    // MD3 motion
    Behavior on opacity {
        NumberAnimation {
            duration: Config.motion.duration.short4
            easing.type: Config.motion.easing.standard
        }
    }
}
