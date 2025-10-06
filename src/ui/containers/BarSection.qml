import QtQuick
import QtQuick.Layouts
import qs.src.core.config

RowLayout {
    id: root

    property string alignment: "left"      // left, center, right
    property string spacingToken: "medium" // extraSmall, small, medium, large, extraLarge
    property bool animated: true

    // Настройка отступов из токенов
    spacing: Config.spacing[root.spacingToken] || Config.spacing.medium

    // Автоматическое выравнивание
    Layout.alignment: {
        switch(alignment) {
            case "left": return Qt.AlignLeft | Qt.AlignVCenter
            case "center": return Qt.AlignHCenter | Qt.AlignVCenter
            case "right": return Qt.AlignRight | Qt.AlignVCenter
            default: return Qt.AlignLeft | Qt.AlignVCenter
        }
    }

    // Анимации для spacing
    Behavior on spacing {
        enabled: root.animated
        NumberAnimation {
            duration: Config.motion.duration.short3
            easing.type: Config.motion.easing.standard
        }
    }

    // Валидация alignment
    onAlignmentChanged: {
        const validAlignments = ["left", "center", "right"]
        if (!validAlignments.includes(alignment)) {
            console.warn(`BarSection: неизвестное выравнивание "${alignment}", используется left`)
        }
    }

    // Валидация spacing
    Component.onCompleted: {
        if (!Config.spacing[root.spacingToken]) {
            console.warn(`BarSection: неизвестный spacing "${root.spacingToken}", используется medium`)
        }
    }
}