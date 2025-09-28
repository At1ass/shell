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

    implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding, 36)
    implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, 88)

    background: Rectangle {
        id: bg
        radius: Config.shape.medium
        border.width: control.variant === "outlined" ? 1 : 0
        border.color: control.variant === "outlined"
                ? Config.colors.outline
                : "transparent"
        color: backgroundColor()

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Config.colors.surfaceText
            opacity: control.down ? 0.16 : control.hovered ? 0.08 : 0.0
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
        colorRole: control.enabled ? textColorRole() : "surfaceVariantText"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    function textColorRole() {
        switch (control.variant) {
        case "filled":
            return "primaryText"
        case "outlined":
        case "text":
            return "primary"
        default:
            return "primaryContainerText"
        }
    }
}
