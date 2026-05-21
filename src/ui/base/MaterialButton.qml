import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.src.core.config
import "." as Base

// Material Design 3 button. Variants: filled, tonal, elevated, outlined, text.
Button {
    id: control

    property string variant: "tonal" // filled, tonal, elevated, outlined, text

    // MD3 button padding: 24dp horizontal, pill shape, 40dp min height.
    leftPadding: Tokens.spacing.large
    rightPadding: Tokens.spacing.large
    topPadding: Tokens.spacing.small
    bottomPadding: Tokens.spacing.small

    implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding, 40)
    implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, 88)

    readonly property bool _elevated: variant === "elevated"

    // Container fill per variant (disabled → onSurface @ 12%).
    function _containerColor() {
        if (!control.enabled) {
            return (variant === "outlined" || variant === "text")
                ? "transparent"
                : Qt.alpha(Theme.onSurface, Tokens.state.disabledContainerOpacity)
        }
        switch (variant) {
        case "filled":   return Theme.primary
        case "elevated": return Theme.surfaceContainerLow
        case "outlined":
        case "text":     return "transparent"
        default:         return Theme.secondaryContainer // tonal
        }
    }

    // Label / state-layer "on" color per variant.
    function _contentColor() {
        if (!control.enabled) return Qt.alpha(Theme.onSurface, Tokens.state.disabledContentOpacity)
        switch (variant) {
        case "filled": return Theme.onPrimary
        case "tonal":  return Theme.onSecondaryContainer
        default:       return Theme.primary // elevated, outlined, text
        }
    }

    background: Item {
        // Elevated variant casts a level-1 shadow.
        MultiEffect {
            source: bg
            anchors.fill: bg
            z: -1
            visible: control._elevated && control.enabled
            shadowEnabled: visible
            shadowColor: Qt.rgba(0, 0, 0, Tokens.elevation.level1.shadowOpacity)
            blurMax: 64
            shadowBlur: Tokens.elevation.level1.shadowRadius / 64
            shadowVerticalOffset: Tokens.elevation.level1.shadowVerticalOffset
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Tokens.shape.button
            color: control._containerColor()
            border.width: control.variant === "outlined" ? 1 : 0
            border.color: control.variant === "outlined"
                    ? (control.enabled ? Theme.outline : Qt.alpha(Theme.onSurface, Tokens.state.disabledContainerOpacity))
                    : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            // MD3 state layer (tinted with the content "on" color).
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: control._contentColor()
                opacity: !control.enabled ? 0.0
                       : control.down ? Tokens.stateLayer.pressedOpacity
                       : control.hovered ? Tokens.stateLayer.hoverOpacity : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }
            }
        }
    }

    contentItem: Base.MaterialText {
        text: control.text
        textStyle: "labelLarge"
        color: control._contentColor()
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
