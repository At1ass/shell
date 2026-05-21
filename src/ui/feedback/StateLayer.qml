import QtQuick
import qs.src.core.config

// Material Design 3 State Layer
// Universal overlay for hover/pressed/focus/dragged feedback, plus an optional keyboard
// focus ring. Root is an Item so the focus ring can render at full opacity while the
// state fill animates to its (low) state-layer opacity.
Item {
    id: root

    // Properties
    property Item target: parent
    property color layerColor: Theme.onSurface
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool dragged: false

    // Focus ring
    property bool showFocusRing: true
    property color ringColor: Theme.primary

    readonly property real _radius: (target && target.radius !== undefined) ? target.radius : 0

    anchors.fill: target

    // State fill
    Rectangle {
        anchors.fill: parent
        radius: root._radius
        color: root.layerColor
        opacity: {
            if (root.dragged) return Tokens.stateLayer.draggedOpacity
            if (root.pressed) return Tokens.stateLayer.pressedOpacity
            if (root.focused) return Tokens.stateLayer.focusOpacity
            if (root.hovered) return Tokens.stateLayer.hoverOpacity
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

    // Keyboard focus ring (full opacity, sits just outside the target)
    Rectangle {
        visible: root.focused && root.showFocusRing
        anchors.fill: parent
        anchors.margins: -Tokens.focusRing.offset
        radius: root._radius + Tokens.focusRing.offset
        color: "transparent"
        border.width: Tokens.focusRing.width
        border.color: root.ringColor
    }
}
