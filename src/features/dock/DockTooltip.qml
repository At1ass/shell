pragma ComponentBehavior: Bound

import QtQuick
import qs.src.ui.base
import qs.src.core.config
import qs.src.ui.feedback

// Small MD3 tooltip for the hovered dock icon (app name + window count). Rendered in-window
// on the bar's inner side, centered on the icon along the main axis. Passive (no input, so
// it needs no mask region); the coordinator decides when to show it.
MaterialTooltip {
    id: root

    property real center: 0            // along-axis center (x for horizontal, y for vertical)
    property bool showing: false
    property Item anchorItem: null     // dock bar
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"
    readonly property int _gap: Tokens.spacing.extraSmall
    readonly property int _margin: Tokens.spacing.small

    visible: showing || opacity > 0
    opacity: showing && text !== "" ? 1 : 0
    Behavior on opacity {
        MotionAnimation { duration: Tokens.motion.duration.short2; curve: "standard" }
    }

    maximumWidth: Math.max(Tokens.spacing.large,
        Math.min(Tokens.size.fieldWidth + Tokens.spacing.large * 2,
            parent.width - (vertical ? (anchorItem?.width ?? 0) : 0) - _margin * 2 - _gap))
    maximumHeight: Math.max(Tokens.spacing.large,
        parent.height - (vertical ? 0 : (anchorItem?.height ?? 0)) - _margin * 2 - _gap)

    x: {
        if (!anchorItem) return 0
        if (vertical)
            return position === "left" ? (anchorItem.x + anchorItem.width + _gap)
                                       : (anchorItem.x - width - _gap)
        return Math.max(_margin, Math.min(center - width / 2, parent.width - width - _margin))
    }
    y: {
        if (!anchorItem) return 0
        if (vertical)
            return Math.max(_margin, Math.min(center - height / 2, parent.height - height - _margin))
        return position === "top" ? (anchorItem.y + anchorItem.height + _gap)
                                  : (anchorItem.y - height - _gap)
    }

}
