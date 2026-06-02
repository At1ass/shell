pragma ComponentBehavior: Bound

import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Small MD3 tooltip for the hovered dock icon (app name + window count). Rendered in-window
// on the bar's inner side, centered on the icon along the main axis. Passive (no input, so
// it needs no mask region); the coordinator decides when to show it.
Surface {
    id: root

    property string text: ""
    property real center: 0            // along-axis center (x for horizontal, y for vertical)
    property bool showing: false
    property Item anchorItem: null     // dock bar
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"
    readonly property int _gap: Tokens.spacing.extraSmall
    readonly property int _margin: Tokens.spacing.small

    visible: showing && text !== ""
    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.9
    transformOrigin: position === "bottom" ? Item.Bottom
                   : position === "top" ? Item.Top
                   : position === "left" ? Item.Left : Item.Right

    Behavior on opacity {
        NumberAnimation { duration: Tokens.motion.duration.short3 }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.emphasizedDecelerate
            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
        }
    }

    elevation: 2
    radius: Tokens.shape.small
    color: Theme.surfaceContainerHigh

    implicitWidth: label.implicitWidth + Tokens.spacing.medium * 2
    implicitHeight: label.implicitHeight + Tokens.spacing.small * 2

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

    MaterialText {
        id: label
        anchors.centerIn: parent
        text: root.text
        textStyle: "labelMedium"
        colorRole: "onSurface"
    }
}
