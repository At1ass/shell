pragma Singleton

import QtQml
import qs.src.core.config

// Shared reservation for the bar and surfaces positioned beside it.
QtObject {
    readonly property int reservation: AppConfig.moduleEnabled("bar") ? height : 0
    readonly property int height: Math.ceil(Math.max(AppConfig.barHeight,
        Tokens.typography.titleLarge.lineHeight + Tokens.spacing.extraSmall * 2,
        Tokens.touchTarget.minimum))
}
