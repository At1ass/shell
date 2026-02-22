import QtQuick
import QtQuick.Controls
import qs.src.core.config

Pane {
    id: card

    // property bool outlined: true
    property bool outlined: false
    property color color: Theme.surfaceContainerHigh
    property int radius: Tokens.shape.large

    clip: true  // если хотите, чтобы контент не вылезал за скругления
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    background: Rectangle {
        // radius: Tokens.shape.large
        // color: Theme.surfaceContainerHigh
        radius: card.radius
        color: card.color
        border.width: outlined ? 1 : 0
        border.color: outlined ? Theme.outlineVariant : "transparent"
    }
}
