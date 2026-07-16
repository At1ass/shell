import QtQuick
import qs.src.core.config

// Material Design 3 text component. Style and color resolve once per
// textStyle/colorRole change (cached lookups, no per-frame resolution).
Text {
    id: root

    property string textStyle: "bodyMedium"
    property string colorRole: "onSurface"

    readonly property var currentStyle: Tokens.typography[textStyle] || Tokens.typography.bodyMedium
    readonly property color resolvedColor: Theme[colorRole] || Theme.onSurface

    font.family: Tokens.typography.fontFamily
    // MD3 type-scale sizes are in sp → map to Qt pixelSize (DPI-independent),
    // NOT pointSize (which is physical points and varies with font DPI).
    font.pixelSize: currentStyle.size
    font.weight: currentStyle.weight
    font.letterSpacing: currentStyle.letterSpacing

    renderType: Text.NativeRendering
    color: resolvedColor
}
