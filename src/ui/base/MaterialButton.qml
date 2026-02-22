import QtQuick
import QtQuick.Controls
import qs.src.core.config
import "." as Base

Button {
    id: control

    property string variant: "tonal" // tonal, filled, outlined, text

    leftPadding: Tokens.spacing.medium
    rightPadding: Tokens.spacing.medium
    topPadding: Tokens.spacing.small
    bottomPadding: Tokens.spacing.small

    implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding, 40)
    implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, 88)

    background: Rectangle {
        id: bg
        radius: Tokens.shape.medium
        border.width: control.variant === "outlined" ? 1 : 0
        border.color: control.variant === "outlined"
                ? Theme.outline
                : "transparent"
        color: backgroundColor()

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
            }
        }

        // MD3 State Layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.onSurface
            opacity: control.down ? Tokens.stateLayer.pressedOpacity :
                     control.hovered ? Tokens.stateLayer.hoverOpacity : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                }
            }
        }

        function backgroundColor() {
            if (!control.enabled) return Qt.alpha(Theme.surfaceContainerHigh, 0.60)
            switch (control.variant) {
            case "filled":
                return Theme.primary
            case "outlined":
            case "text":
                return "transparent"
            default:
                return Qt.alpha(Theme.primaryContainer, 0.85)
            }
        }
    }

    contentItem: Base.MaterialText {
        text: control.text
        textStyle: "labelLarge"
        colorRole: control.enabled ? textColorRole() : "onSurfaceVariant"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    function textColorRole() {
        switch (control.variant) {
        case "filled":
            return "onPrimary"
        case "outlined":
        case "text":
            return "primary"
        default:
            return "onPrimaryContainer"
        }
    }
}
