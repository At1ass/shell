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

    property string hintText: ""
    property real center: 0            // along-axis center (x for horizontal, y for vertical)
    property bool showing: false
    property Item anchorItem: null     // dock bar
    property string position: "bottom"

    readonly property bool vertical: position === "left" || position === "right"
    readonly property int _gap: Tokens.spacing.extraSmall
    readonly property int _margin: Tokens.spacing.small

    readonly property bool _presenting: showing && hintText !== ""
    property string _retainedText: ""
    property real _retainedX: 0
    property real _retainedY: 0
    property real _retainedMaximumWidth: Tokens.size.fieldWidth
    property real _retainedMaximumHeight: Tokens.size.listItem

    // The producer may clear its owner/text before the opacity animation ends.
    // Retain one complete visual snapshot until a new active hint replaces it.
    function _retain() {
        if (!_presenting) return
        _retainedText = hintText
        _retainedMaximumWidth = _availableWidth
        _retainedMaximumHeight = _availableHeight
        _retainedX = _targetX
        _retainedY = _targetY
    }
    on_PresentingChanged: _retain()
    onHintTextChanged: _retain()
    on_AvailableWidthChanged: if (_presenting) _retainedMaximumWidth = _availableWidth
    on_AvailableHeightChanged: if (_presenting) _retainedMaximumHeight = _availableHeight
    on_TargetXChanged: if (_presenting) _retainedX = _targetX
    on_TargetYChanged: if (_presenting) _retainedY = _targetY

    text: _retainedText
    maximumWidth: _retainedMaximumWidth
    maximumHeight: _retainedMaximumHeight
    x: _retainedX
    y: _retainedY
    visible: _presenting || opacity > 0
    opacity: _presenting ? 1 : 0
    Behavior on opacity {
        MotionAnimation { duration: Tokens.motion.duration.short2; curve: "standard" }
    }

    readonly property real _availableWidth: Math.max(Tokens.spacing.large,
        Math.min(Tokens.size.fieldWidth + Tokens.spacing.large * 2,
            parent.width - (vertical ? (anchorItem?.width ?? 0) : 0) - _margin * 2 - _gap))
    readonly property real _availableHeight: Math.max(Tokens.spacing.large,
        parent.height - (vertical ? 0 : (anchorItem?.height ?? 0)) - _margin * 2 - _gap)

    readonly property real _targetX: {
        if (!anchorItem) return 0
        if (vertical)
            return position === "left" ? (anchorItem.x + anchorItem.width + _gap)
                                       : (anchorItem.x - width - _gap)
        return Math.max(_margin, Math.min(center - width / 2, parent.width - width - _margin))
    }
    readonly property real _targetY: {
        if (!anchorItem) return 0
        if (vertical)
            return Math.max(_margin, Math.min(center - height / 2, parent.height - height - _margin))
        return position === "top" ? (anchorItem.y + anchorItem.height + _gap)
                                  : (anchorItem.y - height - _gap)
    }

}
