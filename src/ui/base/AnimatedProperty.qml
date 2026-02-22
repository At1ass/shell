import QtQuick
import qs.src.core.config

QtObject {
    id: root

    property real value: 0
    property string duration: "medium2"     // duration token from Tokens.motion.duration
    property string easing: "standard"     // easing token from Tokens.motion.easing
    property bool enabled: true

    // Получение длительности из токенов
    readonly property int actualDuration: {
        return Tokens.motion.duration[duration] || Tokens.motion.duration.medium2
    }

    // Получение easing из токенов
    readonly property int actualEasing: {
        return Tokens.motion.easing[easing] || Tokens.motion.easing.standard
    }

    // Behavior для анимации значения
    Behavior on value {
        enabled: root.enabled
        NumberAnimation {
            duration: root.actualDuration
            easing.type: root.actualEasing
        }
    }

    // Хелпер функции для создания специфичных анимаций
    function createColorAnimation(target, property) {
        return Qt.createQmlObject(`
            import QtQuick
            ColorAnimation {
                target: ${target}
                property: "${property}"
                duration: ${root.actualDuration}
                easing.type: ${root.actualEasing}
            }
        `, root)
    }

    function createScaleAnimation(target) {
        return Qt.createQmlObject(`
            import QtQuick
            NumberAnimation {
                target: ${target}
                property: "scale"
                duration: ${root.actualDuration}
                easing.type: ${root.actualEasing}
            }
        `, root)
    }

    // Валидация токенов
    Component.onCompleted: {
        if (!Tokens.motion.duration[duration]) {
            console.warn(`AnimatedProperty: неизвестный duration "${duration}", используется medium2`)
        }
        if (!Tokens.motion.easing[easing]) {
            console.warn(`AnimatedProperty: неизвестный easing "${easing}", используется standard`)
        }
    }
}