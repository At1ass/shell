import QtQuick
import QtQuick.Controls
import qs.src.core.config

Pane {
    id: card

    property bool outlined: true

    clip: true  // если хотите, чтобы контент не вылезал за скругления

    background: Rectangle {
        radius: Config.shape.large
        color: Config.colors.surfaceContainerHigh
        border.width: outlined ? 1 : 0
        border.color: outlined ? Config.colors.outlineVariant : "transparent"
    }
}
