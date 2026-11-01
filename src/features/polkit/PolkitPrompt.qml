pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

// Presentation only: the adapter owns PAM, request guards and password lifetime.
Surface {
    id: root
    property string message: ""
    property var identities: []
    property int identityIndex: 0
    property string prompt: ""
    property bool responseVisible: false
    property bool responseRequired: false
    property string failureMessage: ""
    property bool submitting: false
    property alias password: field.text
    signal submitted()
    signal cancelled()
    signal identitySelected(int index)

    function focusInput() { field.inputItem.forceActiveFocus() }

    elevation: 3
    radius: Tokens.shape.extraLarge
    implicitWidth: Tokens.size.fieldWidth + Tokens.spacing.extraHuge * 4
    implicitHeight: layout.implicitHeight + Tokens.spacing.large * 2
    Keys.onEscapePressed: root.cancelled()

    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.large
        ColumnLayout {
            id: layout
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium
                MaterialIcon {
                    iconName: "admin_panel_settings"
                    fontSize: Tokens.iconSize.large
                    colorRole: "primary"
                }
                MaterialText {
                    objectName: "polkitTitle"
                    Layout.fillWidth: true
                    text: "Authentication required"
                    textStyle: "titleMedium"
                    colorRole: "onSurface"
                    wrapMode: Text.Wrap
                }
            }
            MaterialText {
                Layout.fillWidth: true
                text: root.message
                textFormat: Text.PlainText
                textStyle: "bodyMedium"
                colorRole: "onSurfaceVariant"
                wrapMode: Text.Wrap
                visible: text.length > 0
            }
            MaterialComboBox {
                objectName: "polkitIdentity"
                Layout.fillWidth: true
                visible: root.identities.length > 1
                model: root.identities
                controlled: true
                currentIndex: root.identityIndex
                onActivated: index => root.identitySelected(index)
            }
            // Keep the editor during intermediate authentication stages.
            MaterialTextField {
                id: field
                objectName: "polkitPassword"
                Layout.fillWidth: true
                label: root.prompt || "Password"
                placeholderText: root.prompt
                password: !root.responseVisible
                onAccepted: root.submitted()
            }
            MaterialText {
                Layout.fillWidth: true
                text: root.failureMessage
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                colorRole: "error"
                wrapMode: Text.Wrap
                visible: text.length > 0
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= cancelButton.implicitWidth + submitButton.implicitWidth + columnSpacing ? 2 : 1
                columnSpacing: Tokens.spacing.small
                rowSpacing: Tokens.spacing.small
                MaterialButton {
                    id: cancelButton
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Cancel"
                    variant: "text"
                    onClicked: root.cancelled()
                }
                MaterialButton {
                    id: submitButton
                    objectName: "polkitSubmit"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Authenticate"
                    variant: "filled"
                    enabled: root.responseRequired && !root.submitting && field.text.length > 0
                    onClicked: root.submitted()
                }
            }
        }
    }
}
