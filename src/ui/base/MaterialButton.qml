import QtQuick
import QtQuick.Controls
import qs.src.core.config
import "." as Base

// Material Design 3 button. Variants: filled, tonal, elevated, outlined, text.
Button {
    id: control

    property string variant: "tonal" // filled, tonal, elevated, outlined, text

    // Space follows the native button press/release path. Return activation
    // depends on the platform theme, so make both Enter keys explicit here.
    focusPolicy: Qt.StrongFocus
    function _activateFromKey(event) {
        event.accepted = true
        if (!event.isAutoRepeat) control.click()
    }
    Keys.onReturnPressed: event => control._activateFromKey(event)
    Keys.onEnterPressed: event => control._activateFromKey(event)

    // MD3 button padding: 24dp horizontal, pill shape, 40dp min height.
    leftPadding: Tokens.spacing.large
    rightPadding: Tokens.spacing.large
    topPadding: Tokens.spacing.small
    bottomPadding: Tokens.spacing.small

    implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding, Tokens.size.control)
    implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Tokens.size.buttonMinimumWidth)

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
        Base.ElevationShadow {
            target: bg
            level: 1
            visible: control._elevated && control.enabled
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Tokens.shape.pill
            color: control._containerColor()
            border.width: control.variant === "outlined" ? Tokens.size.outline : 0
            border.color: control.variant === "outlined"
                    ? (control.enabled ? Theme.outline : Qt.alpha(Theme.onSurface, Tokens.state.disabledContainerOpacity))
                    : "transparent"

            Behavior on color {
                Base.MotionColorAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "standard"
                }
            }
            Behavior on border.color {
                Base.MotionColorAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "standard"
                }
            }

            // MD3 state layer (tinted with the content "on" color).
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: control._contentColor()
                opacity: !control.enabled ? 0.0
                       : control.down ? Tokens.stateLayer.pressedOpacity
                       : control.visualFocus ? Tokens.stateLayer.focusOpacity
                       : control.hovered ? Tokens.stateLayer.hoverOpacity : 0.0

                Behavior on opacity {
                    Base.MotionAnimation {
                        duration: Tokens.motion.duration.short4
                        curve: "standard"
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
