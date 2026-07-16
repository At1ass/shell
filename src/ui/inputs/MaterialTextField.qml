import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 text field (outlined or filled), with placeholder, optional leading/
// trailing icons, and focus highlighting. Placeholder-based (no floating-label notch) for
// robustness across any surface background.
Item {
    id: root

    property alias text: input.text
    property alias inputItem: input
    // Prefer a validator over inputMask: masks make an "empty" field
    // non-empty (mask literals live in `text`), breaking every
    // emptiness/placeholder check downstream.
    property alias validator: input.validator
    property string placeholderText: ""
    property string variant: "outlined" // "outlined" | "filled"
    property string leadingIcon: ""
    property string trailingIcon: ""
    property bool password: false

    signal accepted()
    signal textEdited()
    signal trailingClicked()

    implicitHeight: 56
    implicitWidth: 240

    readonly property bool _filled: variant === "filled"
    readonly property color _accent: input.activeFocus ? Theme.primary : Theme.outline

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    Rectangle {
        id: box
        anchors.fill: parent
        radius: root._filled ? Tokens.shape.extraSmall : Tokens.shape.small
        color: root._filled ? Theme.surfaceContainerHighest : "transparent"
        border.width: root._filled ? 0 : (input.activeFocus ? 2 : 1)
        border.color: root._accent

        Behavior on border.color {
            ColorAnimation {
                duration: Tokens.motion.duration.short3
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }

        // Filled-variant active underline
        Rectangle {
            visible: root._filled
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: input.activeFocus ? 2 : 1
            color: root._accent
        }
    }

    MaterialIcon {
        id: leading
        visible: root.leadingIcon !== ""
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.medium
        anchors.verticalCenter: parent.verticalCenter
        iconName: root.leadingIcon
        fontSize: Tokens.iconSize.large
        iconColor: Theme.onSurfaceVariant
        backgroundColor: "transparent"
    }

    IconButton {
        id: trailing
        visible: root.trailingIcon !== ""
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        variant: "standard"
        iconName: root.trailingIcon
        iconSize: Tokens.iconSize.large
        containerSize: 36
        touchTargetSize: 40
        onClicked: root.trailingClicked()
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.leadingIcon !== "" ? leading.x + leading.width + Tokens.spacing.small : Tokens.spacing.medium
        anchors.rightMargin: root.trailingIcon !== "" ? trailing.width + Tokens.spacing.small : Tokens.spacing.medium
        verticalAlignment: TextInput.AlignVCenter
        enabled: root.enabled
        clip: true
        color: Theme.onSurface
        selectionColor: Theme.primary
        selectedTextColor: Theme.onPrimary
        selectByMouse: true
        font.family: Tokens.typography.fontFamily
        font.pixelSize: Tokens.typography.bodyLarge.size
        echoMode: root.password ? TextInput.Password : TextInput.Normal

        onAccepted: root.accepted()
        onTextChanged: root.textEdited()

        MaterialText {
            visible: input.text.length === 0
            text: root.placeholderText
            textStyle: "bodyLarge"
            color: Theme.onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
