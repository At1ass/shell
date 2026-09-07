import QtQuick
import qs.src.core.config

// A thin horizontal gauge: how full something is, read without reading a number.
//
// It exists because the alternative at every call site was a raw Rectangle
// holding another raw Rectangle, which is what §10.3 is about -- and because a
// gauge has one job that is easy to get subtly wrong. The fill is clamped, so a
// service reporting 103% or a negative delta cannot draw outside the track.
//
// Track and fill are a value pair of ONE colour rather than two roles: this is a
// quantity, not a state, and colouring it would spend accent on something that
// changes every two seconds.
Rectangle {
    id: root

    // 0..1. Values outside are clamped, not asserted away.
    property real value: 0
    readonly property real _fraction: Math.max(0, Math.min(1, root.value))

    implicitHeight: 2
    height: implicitHeight
    radius: height / 2
    color: Qt.alpha(Theme.onSurface, Tokens.stateLayer.draggedOpacity)

    Rectangle {
        width: parent.width * root._fraction
        height: parent.height
        radius: parent.radius
        color: Theme.onSurfaceVariant

        Behavior on width {
            MotionAnimation {
                duration: Tokens.motion.duration.medium2
                curve: "standard"
            }
        }
    }
}
