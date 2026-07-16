import QtQuick
import qs.src.core.config

// NumberAnimation with an MD3 easing preset fused in: `curve` selects BOTH
// easing.type and the bezier points, so they can never diverge. Hand-written
// easing.type/easing.bezierCurve pairs silently degrade to linear when either
// half is missing — prefer this component (tools/check.sh polices the pairs
// that remain).
//
//   Behavior on opacity { MotionAnimation { curve: "emphasizedDecelerate" } }
NumberAnimation {
    // One of: "standard", "emphasized", "emphasizedDecelerate", "emphasizedAccelerate"
    property string curve: "standard"

    duration: Tokens.motion.duration.short4
    easing.type: Tokens.motion.easing[curve] ?? Tokens.motion.easing.standard
    easing.bezierCurve: Tokens.motion.easing[curve + "Points"] ?? Tokens.motion.easing.standardPoints
}
