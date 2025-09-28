import QtQuick
import qs.src.core.config

QtObject {
    id: root

    property real value: 0
    property string duration: "medium2"     // duration token from Config.motion.duration
    property string easing: "standard"     // easing token from Config.motion.easing
    property bool enabled: true

    // Получение длительности из токенов
    readonly property int actualDuration: {
        return Config.motion.duration[duration] || Config.motion.duration.medium2
    }

    // Получение easing из токенов
    readonly property int actualEasing: {
        return Config.motion.easing[easing] || Config.motion.easing.standard
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
        if (!Config.motion.duration[duration]) {
            console.warn(`AnimatedProperty: неизвестный duration "${duration}", используется medium2`)
        }
        if (!Config.motion.easing[easing]) {
            console.warn(`AnimatedProperty: неизвестный easing "${easing}", используется standard`)
        }
    }
}