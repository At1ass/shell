import QtQuick
import qs.src.core.config

// Elevation tint for TRANSLUCENT surfaces (bar/dock over wallpaper) where
// the tonal surfaceRole of Surface{} cannot apply. Opacity comes from the
// elevation token scale — never hardcode it at the call site.
Rectangle {
    id: root

    // Elevation level 0–5; picks Tokens.elevation.level(n).tintOpacity.
    property int level: 1

    anchors.fill: parent
    radius: (parent as Rectangle)?.radius ?? 0
    color: Theme.primary
    opacity: Tokens.elevation.level(level).tintOpacity
}
