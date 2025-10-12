import QtQuick
import qs.src.core.config

// Optimized Material Design 3 Text component
// Caches style lookups to avoid repeated property resolution
Text {
    id: root

    property string textStyle: "bodyMedium"
    property string colorRole: "onSurface"

    // ✅ Кэшируем style один раз при изменении textStyle
    readonly property var currentStyle: Config.typography[textStyle] || Config.typography.bodyMedium

    // ✅ Кэшируем color один раз при изменении colorRole
    readonly property color resolvedColor: Config.colors[colorRole] || Config.colors.onSurface

    // Автоматическое применение Material Design 3 типографики
    font.family: Config.typography.fontFamily
    font.pointSize: currentStyle.size
    font.weight: currentStyle.weight
    font.letterSpacing: currentStyle.letterSpacing

    renderType: Text.NativeRendering // Улучшенное сглаживание шрифтов
    color: resolvedColor
}
