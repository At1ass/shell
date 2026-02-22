import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
// import "." as Base

CheckBox {
    id: control

    spacing: Tokens.spacing.small
    leftPadding: 0

    indicator: Rectangle {
        width: 18
        height: 18
        y: parent.height / 2 - height / 2
        radius: Tokens.shape.small
        color: control.checked
               ? (control.enabled ? Theme.primary : Theme.surfaceContainerHigh)
               : Theme.surface
        border.width: control.checked ? 0 : 1
        border.color: control.checked ? Qt.rgba(0, 0, 0, 0) : Theme.outline

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.primary
            opacity: (!control.checked && control.hovered && control.enabled) ? 0.08 : 0
        }

        MaterialText {
            anchors.centerIn: parent
            text: control.checked ? "✓" : ""
            textStyle: "labelLarge"
            colorRole: control.checked ? "onPrimary" : "onSurface"
        }
    }

    contentItem: MaterialText {
        leftPadding: control.indicator && !control.mirrored ? control.indicator.width + control.spacing : 0
        rightPadding: control.indicator && control.mirrored ? control.indicator.width + control.spacing : 0
        text: control.text
        textStyle: "bodyMedium"
        colorRole: control.enabled ? "onSurface" : "onSurfaceVariant"
        verticalAlignment: Text.AlignVCenter
    }
}
