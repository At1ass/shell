import QtQuick
import qs.config

Text {
    id: root

    property string textStyle: "bodyMedium"
    property string colorRole: "onSurface"

    readonly property var currentStyle: Tokens.typography[textStyle] || Tokens.typography.bodyMedium
    readonly property color resolvedColor: GreeterTheme[colorRole] || GreeterTheme.onSurface

    font.family: Tokens.typography.fontFamily
    // MD3 sp sizes → Qt pixelSize (matches main shell MaterialText)
    font.pixelSize: currentStyle.size
    font.weight: currentStyle.weight
    font.letterSpacing: currentStyle.letterSpacing

    renderType: Text.NativeRendering
    color: resolvedColor
}
