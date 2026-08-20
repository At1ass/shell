import QtQuick
import qs.src.core.config

// ColorAnimation counterpart of MotionAnimation: `curve` selects BOTH
// easing.type and the bezier points, so they can never diverge.
//
// MotionAnimation is a NumberAnimation and cannot stand in for a colour
// transition, which is why a quarter of the shell's hand-written easing pairs
// had no kit component to move to at all.
//
//   Behavior on color { MotionColorAnimation { curve: "standard" } }
ColorAnimation {
    // One of: "standard", "emphasized", "emphasizedDecelerate", "emphasizedAccelerate"
    property string curve: "standard"

    duration: Tokens.motion.duration.short4
    easing.type: Tokens.motion.easing[curve] ?? Tokens.motion.easing.standard
    easing.bezierCurve: Tokens.motion.easing[curve + "Points"] ?? Tokens.motion.easing.standardPoints
}
