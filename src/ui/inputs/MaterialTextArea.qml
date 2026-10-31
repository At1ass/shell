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
    property string label: (labelItem as Text)?.text ?? ""
    property Item labelItem: null
    property string supportingText: ""
    property string errorText: ""

    signal textEdited()
    onActiveFocusChanged: if (activeFocus) input.forceActiveFocus()

    implicitWidth: 240
    readonly property real controlHeight: Math.max(96, input.implicitHeight + Tokens.spacing.medium * 2)
    implicitHeight: controlHeight + (feedback.visible ? feedback.implicitHeight + Tokens.spacing.extraSmall : 0)

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    Rectangle {
        id: box
        height: Math.max(0, root.height - (feedback.visible ? feedback.implicitHeight + Tokens.spacing.extraSmall : 0))
        anchors { top: parent.top; left: parent.left; right: parent.right }
        radius: Tokens.shape.small
        color: "transparent"
        border.width: input.activeFocus ? 2 : 1
        border.color: root.errorText !== "" ? Theme.error : input.activeFocus ? Theme.primary : Theme.outline

        Behavior on border.color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short3
                curve: "standard"
            }
        }
    }

    TextEdit {
        id: input
        property Item focusContext: root
        Accessible.multiLine: true
        Accessible.role: Accessible.EditableText
        Accessible.name: root.Accessible.name || root.label || root.placeholderText
        // Qt rejects a null labelledBy; leave the relationship unset for
        // placeholder-only fields. Visual labels share the field lifetime.
        Binding {
            target: input
            property: "Accessible.labelledBy"
            when: root.labelItem !== null
            value: root.labelItem
            restoreMode: Binding.RestoreNone
        }
        Accessible.description: [root.supportingText, root.errorText].filter(text => text !== "").join(". ")
        anchors.fill: box
        anchors.margins: Tokens.spacing.medium
        enabled: root.enabled
        activeFocusOnTab: root.enabled
        // Let form owners handle navigation before TextEdit inserts a Tab.
        Keys.forwardTo: [root]
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
            Accessible.ignored: true
            text: root.placeholderText
            textStyle: "bodyMedium"
            color: Theme.onSurfaceVariant
        }
    }
    MaterialText {
        id: feedback
        anchors { top: box.bottom; topMargin: Tokens.spacing.extraSmall; left: parent.left; right: parent.right; leftMargin: Tokens.spacing.medium; rightMargin: Tokens.spacing.medium }
        text: root.errorText || root.supportingText
        textFormat: Text.PlainText
        visible: text !== ""
        textStyle: "bodySmall"
        colorRole: root.errorText !== "" ? "error" : "onSurfaceVariant"
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
}
