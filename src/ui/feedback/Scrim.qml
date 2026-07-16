import QtQuick
import qs.src.core.config

// MD3 scrim: Theme.scrim at the token opacity behind modal surfaces.
// Use `shown` (not `visible`) so the fade animation can play.
Rectangle {
    id: root

    property bool shown: false

    anchors.fill: parent
    color: Theme.scrim
    opacity: shown ? Tokens.state.scrimOpacity : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.duration.short4
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }
}
