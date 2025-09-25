import QtQuick
import QtQuick.Controls
import qs.config
import "." as Base

CheckBox {
    id: control

    spacing: Config.spacing.small

    indicator: Rectangle {
        width: 18
        height: 18
        radius: Config.shape.small
        color: control.checked
               ? (control.enabled ? Config.colors.primary : Config.colors.surfaceContainerHigh)
               : Config.colors.surface
        border.width: control.checked ? 0 : 1
        border.color: control.checked ? Qt.rgba(0, 0, 0, 0) : Config.colors.outline

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Config.colors.primary
            opacity: (!control.checked && control.hovered && control.enabled) ? 0.08 : 0
        }

        Base.MaterialText {
            anchors.centerIn: parent
            text: control.checked ? "✓" : ""
            textStyle: "labelLarge"
            colorRole: control.checked ? "primaryText" : "surfaceText"
        }
    }

    contentItem: Base.MaterialText {
        text: control.text
        textStyle: "bodyMedium"
        colorRole: control.enabled ? "surfaceText" : "surfaceVariantText"
        verticalAlignment: Text.AlignVCenter
    }
}
