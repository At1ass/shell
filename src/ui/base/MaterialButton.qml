import QtQuick
import QtQuick.Controls
import qs.src.core.config
import "." as Base

Button {
    id: control

    property string variant: "tonal" // tonal, filled, outlined, text

    leftPadding: Config.spacing.medium
    rightPadding: Config.spacing.medium
    topPadding: Config.spacing.small
    bottomPadding: Config.spacing.small

    implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding, 40)
    implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, 88)

    background: Rectangle {
        id: bg
        radius: Config.shape.medium
        border.width: control.variant === "outlined" ? 1 : 0
        border.color: control.variant === "outlined"
                ? Config.colors.outline
                : "transparent"
        color: backgroundColor()

        Behavior on color {
            ColorAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.standard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.standard
            }
        }

        // MD3 State Layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Config.colors.onSurface
            opacity: control.down ? Config.stateLayer.pressedOpacity :
                     control.hovered ? Config.stateLayer.hoverOpacity : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                    easing.type: Config.motion.easing.standard
                }
            }
        }

        function backgroundColor() {
            if (!control.enabled) return Config.colors.surfaceContainerHigh
            switch (control.variant) {
            case "filled":
                return Config.colors.primary
            case "outlined":
            case "text":
                return "transparent"
            default:
                return Config.colors.primaryContainer
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
