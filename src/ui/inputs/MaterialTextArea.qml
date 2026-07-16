import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Multiline sibling of MaterialTextField (outlined box, placeholder,
// focus highlight). Grows with content; put it inside a Flickable/
// ScrollableList when the surrounding layout is height-constrained.
Item {
    id: root

    property alias text: input.text
    property alias inputItem: input
    property string placeholderText: ""

    signal textEdited()

    implicitWidth: 240
    implicitHeight: Math.max(96, input.implicitHeight + Tokens.spacing.medium * 2)

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    Rectangle {
        anchors.fill: parent
        radius: Tokens.shape.small
        color: "transparent"
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.primary : Theme.outline

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.motion.duration.short3
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }
    }

    TextEdit {
        id: input
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        enabled: root.enabled
        clip: true
        color: Theme.onSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.onPrimary
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        font.family: Tokens.typography.fontFamily
        font.pixelSize: Tokens.typography.bodyMedium.size

        onTextChanged: root.textEdited()

        MaterialText {
            visible: input.text.length === 0
            text: root.placeholderText
            textStyle: "bodyMedium"
            color: Theme.onSurfaceVariant
        }
    }
}
