pragma Singleton
import QtQuick
import qs.src.core.config

/**
 * Библиотека стандартных анимаций Material Design 3
 *
 * Использование:
 *   import qs.src.ui.animations
 *
 *   Rectangle {
 *       color: "red"
 *       Behavior on color { StandardAnimations.color() }
 *   }
 */
Singleton {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // ОСНОВНЫЕ АНИМАЦИИ
    // ═══════════════════════════════════════════════════════════════

    /**
     * Стандартная анимация цвета (ColorAnimation)
     * @param duration - длительность (по умолчанию short4 = 200ms)
     * @param easing - тип easing (по умолчанию standard)
     */
    function color(duration, easing) {
        return colorComponent.createObject(null, {
            duration: duration || Config.motion.duration.short4,
            easing: easing || easingStandard()
        })
    }

    /**
     * Анимация прозрачности (NumberAnimation)
     * @param duration - длительность (по умолчанию short3 = 150ms)
     */
    function opacity(duration, easing) {
        return numberComponent.createObject(null, {
            duration: duration || Config.motion.duration.short3,
            easing: easing || easingStandard()
        })
    }

    /**
     * Анимация ширины/высоты (NumberAnimation)
     * @param duration - длительность (по умолчанию short4 = 200ms)
     */
    function size(duration, easing) {
        return numberComponent.createObject(null, {
            duration: duration || Config.motion.duration.short4,
            easing: easing || easingStandard()
        })
    }

    /**
     * Анимация масштаба (NumberAnimation)
     * @param duration - длительность (по умолчанию medium2 = 300ms)
     */
    function scale(duration, easing) {
        return numberComponent.createObject(null, {
            duration: duration || Config.motion.duration.medium2,
            easing: easing || easingEmphasized()
        })
    }

    /**
     * Анимация позиции (NumberAnimation)
     * @param duration - длительность (по умолчанию medium2 = 300ms)
     */
    function position(duration, easing) {
        return numberComponent.createObject(null, {
            duration: duration || Config.motion.duration.medium2,
            easing: easing || easingEmphasized()
        })
    }

    /**
     * Анимация вращения (NumberAnimation)
     * @param duration - длительность (по умолчанию medium3 = 350ms)
     */
    function rotation(duration, easing) {
        return numberComponent.createObject(null, {
            duration: duration || Config.motion.duration.medium3,
            easing: easing || easingStandard()
        })
    }

    // ═══════════════════════════════════════════════════════════════
    // СПЕЦИАЛИЗИРОВАННЫЕ АНИМАЦИИ
    // ═══════════════════════════════════════════════════════════════

    /**
     * Быстрая анимация цвета для hover эффектов
     */
    function colorFast() {
        return colorComponent.createObject(null, {
            duration: Config.motion.duration.short2,
            easing: easingStandard()
        })
    }

    /**
     * Плавная анимация цвета для переходов
     */
    function colorSmooth() {
        return colorComponent.createObject(null, {
            duration: Config.motion.duration.medium2,
            easing: easingEmphasized()
        })
    }

    /**
     * Анимация появления (fade in)
     */
    function fadeIn() {
        return numberComponent.createObject(null, {
            duration: Config.motion.duration.medium2,
            easing: easingEmphasizedDecelerate()
        })
    }

    /**
     * Анимация исчезновения (fade out)
     */
    function fadeOut() {
        return numberComponent.createObject(null, {
            duration: Config.motion.duration.short4,
            easing: easingEmphasizedAccelerate()
        })
    }

    /**
     * Анимация для state layer (hover/press эффекты)
     */
    function stateLayer() {
        return numberComponent.createObject(null, {
            duration: Config.motion.duration.short3,
            easing: easingStandard()
        })
    }

    // ═══════════════════════════════════════════════════════════════
    // EASING CURVES (Material Design 3)
    // ═══════════════════════════════════════════════════════════════

    function easingStandard() {
        return {
            type: Config.motion.easing.standard,
            bezierCurve: Config.motion.easing.standardPoints
        }
    }

    function easingEmphasized() {
        return {
            type: Config.motion.easing.emphasized,
            bezierCurve: Config.motion.easing.emphasizedPoints
        }
    }

    function easingEmphasizedDecelerate() {
        return {
            type: Config.motion.easing.emphasizedDecelerate,
            bezierCurve: Config.motion.easing.emphasizedDeceleratePoints
        }
    }

    function easingEmphasizedAccelerate() {
        return {
            type: Config.motion.easing.emphasizedAccelerate,
            bezierCurve: Config.motion.easing.emphasizedAcceleratePoints
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ВНУТРЕННИЕ КОМПОНЕНТЫ
    // ═══════════════════════════════════════════════════════════════

    property Component colorComponent: Component {
        ColorAnimation {
            property var easing: ({})
            easing.type: easing.type || Easing.Linear
            easing.bezierCurve: easing.bezierCurve || []
        }
    }

    property Component numberComponent: Component {
        NumberAnimation {
            property var easing: ({})
            easing.type: easing.type || Easing.Linear
            easing.bezierCurve: easing.bezierCurve || []
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // УТИЛИТЫ ДЛЯ СОЗДАНИЯ КАСТОМНЫХ АНИМАЦИЙ
    // ═══════════════════════════════════════════════════════════════

    /**
     * Создать кастомную ColorAnimation
     * @param props - объект с свойствами { duration, easing }
     */
    function createColor(props) {
        return colorComponent.createObject(null, props || {})
    }

    /**
     * Создать кастомную NumberAnimation
     * @param props - объект с свойствами { duration, easing }
     */
    function createNumber(props) {
        return numberComponent.createObject(null, props || {})
    }
}
