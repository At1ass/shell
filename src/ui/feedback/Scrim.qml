import QtQuick
import qs.src.core.config
import qs.src.ui.base

// MD3 scrim: Theme.scrim at the token opacity behind modal surfaces.
// Use `shown` (not `visible`) so the fade animation can play.
//
// Children are allowed — the usual one is a click-to-close MouseArea, which is
// panel-specific and so stays at the call site.
//
// `duration` is a real parameter, not a loophole: MD3 ties the scrim's fade to
// the transition of the surface it sits behind, and panels enter at different
// speeds. The OPACITY is not a parameter — it is the token. Four hand-rolled
// copies of this component existed before, three using a literal 0.32 (equal to
// the token by luck) and the power menu using 0.5 for no recorded reason.
Rectangle {
    id: root

    property bool shown: false
    property int duration: Tokens.motion.duration.medium2

    // Panels gated by a LazyLoader are CREATED with `shown` already true, and a
    // Behavior never runs for a value computed during initialization — those
    // scrims snapped straight to full opacity with no fade at all. Holding the
    // binding at 0 until completion turns the first evaluation into a real
    // change, so the fade plays for them too. Panels that merely toggle `shown`
    // later are unaffected.
    property bool _ready: false
    Component.onCompleted: root._ready = true

    anchors.fill: parent
    color: Theme.scrim
    opacity: root._ready && root.shown ? Tokens.state.scrimOpacity : 0

    Behavior on opacity {
        MotionAnimation {
            duration: root.duration
            curve: "standard"
        }
    }
}
