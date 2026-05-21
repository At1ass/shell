import QtQuick
import QtQuick.Controls
import qs.src.core.config

// Material Design 3 card. Backed by Surface for tonal elevation + shadow.
//
// `elevation` defaults to 0 (flat) to preserve existing in-panel cards. Note: `clip: true`
// (kept for rounded content) will clip a cast drop-shadow — for a *floating* card that needs
// a visible shadow, set `clip: false` on the instance, or use `Surface` directly.
Pane {
    id: card

    property bool outlined: false
    property color color: Theme.surfaceContainerHigh
    property int radius: Tokens.shape.large
    property int elevation: 0

    clip: true
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    background: Surface {
        elevation: card.elevation
        radius: card.radius
        color: card.color
        outlined: card.outlined
    }
}
