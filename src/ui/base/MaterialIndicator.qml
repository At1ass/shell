import QtQuick
import qs.src.core.config

Rectangle {
    id: root

    property string size: "small"        // small, medium, large
    property string colorRole: "outline" // any color from Config.colors
    property bool animated: true
    property string shape: "circle"      // circle, rounded, square

    // Размеры согласно Material Design
    readonly property var sizes: ({
        "extraSmall": 4,
        "small": 8,
        "medium": 12,
        "large": 16,
        "extraLarge": 20
    })

    // Автоматические размеры
    width: sizes[size] || sizes.small
    height: width

    // Автоматический радиус в зависимости от формы
    radius: {
        switch(shape) {
            case "circle": return width / 2
            case "rounded": return Config.shape.extraSmall
            case "square": return 0
            default: return width / 2
        }
    }

    // Автоматический цвет из токенов
    color: Config.colors[colorRole] || Config.colors.outline

    // Анимации
    Behavior on width {
        enabled: root.animated
        NumberAnimation {
            duration: Config.motion.duration.short2
            easing.type: Config.motion.easing.standard
        }
    }

    Behavior on height {
        enabled: root.animated
        NumberAnimation {
            duration: Config.motion.duration.short2
            easing.type: Config.motion.easing.standard
        }
    }

    Behavior on color {
        enabled: root.animated
        ColorAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.standard
        }
    }

    // Валидация размера
    onSizeChanged: {
        if (!sizes[size]) {
            console.warn(`MaterialIndicator: неизвестный размер "${size}", используется small`)
        }
    }
}