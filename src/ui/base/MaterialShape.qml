import QtQuick
import qs.src.core.config

// Flat decoration/image backing/mask. Unlike Surface, this has no content
// wrapper, shadow or implicit motion. Controls still use StateLayer; elevated
// containers use Surface. Keeping a Rectangle root preserves shader-mask types.
Rectangle {
    property string colorRole: "surfaceContainer"
    color: Theme[colorRole] ?? Theme.surfaceContainer
    radius: Tokens.shape.none
    border.color: Theme.outlineVariant
}
