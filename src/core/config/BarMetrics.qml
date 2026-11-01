pragma Singleton

import QtQml
import qs.src.core.config

// Shared reservation for the bar and surfaces positioned beside it.
QtObject {
    readonly property int reservation: AppConfig.moduleEnabled("bar") ? height : 0
    readonly property int verticalPadding: Tokens.spacing.extraSmall
    readonly property int iconSize: Tokens.typography.titleLarge.size
    readonly property int minimumContentHeight: {
        let result = Tokens.typography.titleLarge.lineHeight
        for (const widget of AppConfig.barWidgets) {
            if (widget.enabled === false || widget.type !== "tray") continue
            result = Math.max(result, (widget.settings?.iconSize ?? Tokens.iconSize.medium)
                + Tokens.spacing.extraSmall * 2)
        }
        return Math.ceil(result)
    }
    readonly property int height: Math.ceil(Math.max(AppConfig.barHeight,
        minimumContentHeight + verticalPadding * 2))
    readonly property int widgetHeight: height - verticalPadding * 2
    readonly property int buttonSize: Math.min(widgetHeight,
        Math.max(Tokens.size.iconButton, Tokens.touchTarget.minimum))
}
