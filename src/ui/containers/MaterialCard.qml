import QtQuick
import QtQuick.Controls
import qs.src.core.config

Pane {
    id: card

    property bool outlined: true
    property color color: Config.colors.surfaceContainerHigh
    property int radius: Config.shape.large

    clip: true  // если хотите, чтобы контент не вылезал за скругления
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    background: Rectangle {
        // radius: Config.shape.large
        // color: Config.colors.surfaceContainerHigh
        radius: card.radius
        color: card.color
        border.width: outlined ? 1 : 0
        border.color: outlined ? Config.colors.outlineVariant : "transparent"
    }
}
