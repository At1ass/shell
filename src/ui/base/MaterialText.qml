import QtQuick
import qs.src.core.config

Text {
    id: root

    property string textStyle: "bodyMedium"
    property string colorRole: "onSurface"

    // Автоматическое применение Material Design 3 типографики
    font.family: Config.typography.fontFamily
    // font.pixelSize: getStyleProperty("size")
    font.pointSize: getStyleProperty("size")
    font.weight: getStyleProperty("weight")
    font.letterSpacing: getStyleProperty("letterSpacing")

    renderType: Text.NativeRendering // Улучшенное сглаживание шрифтов
    // Автоматическое применение цвета из токенов
    color: Config.colors[colorRole]

    // Хелпер для получения свойств стиля
    function getStyleProperty(property) {
        const style = Config.typography[textStyle]
        return style ? style[property] : Config.typography.bodyMedium[property]
    }

    // Валидация стиля при изменении
    onTextStyleChanged: {
        if (!Config.typography[textStyle]) {
            console.warn(`MaterialText: неизвестный стиль "${textStyle}", используется bodyMedium`)
        }
    }
}
