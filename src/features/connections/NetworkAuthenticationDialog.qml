pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

Dialog {
    id: root
    property string requestToken: ""
    property string connectionName: ""
    property string message: ""
    property bool requestNew: false
    property string validationError: ""
    property var fields: []
    signal answered(string token, var answers)
    signal rejected(string token)
    property string _shownToken: ""
    property string _name: ""
    property string _message: ""
    property bool _retry: false
    property var _fields: []
    readonly property bool _current: requestToken !== "" && requestToken === _shownToken
    readonly property int desiredHeight: dialogHeight + Tokens.spacing.large * 2
    dialogWidth: width - Tokens.spacing.small * 2
    dialogHeight: column.implicitHeight + Tokens.spacing.medium * 2

    function clearInputs() {
        for (let i = 0; i < editors.count; ++i) {
            const editor = editors.itemAt(i)
            if (editor) { editor.text = ""; editor.password = editor.modelData.secret }
        }
    }
    onRequestTokenChanged: {
        // Clear synchronously: a deferred prompt update must not retain a
        // password from a cancelled request even for one event-loop iteration.
        clearInputs()
        Qt.callLater(root.syncRequest)
    }
    function syncRequest() {
        if (!requestToken) { if (visible) close(); return }
        if (_shownToken === requestToken && visible && opacity > 0) return
        _shownToken = requestToken
        _name = connectionName; _message = message; _retry = requestNew
        _fields = fields
        if (!visible || opacity === 0) open()
        const token = _shownToken
        Qt.callLater(() => {
            if (!root._current || root._shownToken !== token) return
            const first = editors.itemAt(0)
            if (first) first.focusInput()
        })
    }
    function requestClose() { if (_current) rejected(_shownToken) }
    function submit() {
        if (!_current) return
        const answers = {}
        for (let i = 0; i < editors.count; ++i) {
            const editor = editors.itemAt(i)
            if (!editor || !editor.text.length) return
            answers[editor.modelData.key] = editor.text
        }
        answered(_shownToken, answers)
    }
    onClosed: { clearInputs(); _fields = []; _shownToken = "" }
    Component.onDestruction: clearInputs()
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.medium
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            MaterialText {
                Layout.fillWidth: true
                text: "Authenticate " + root._name
                textFormat: Text.PlainText
                textStyle: "titleSmall"
                wrapMode: Text.Wrap
            }
            MaterialText {
                Layout.fillWidth: true
                text: root._message || (root._retry ? "The connection needs new credentials. Check your password and try again." : "Credentials are required to connect.")
                textFormat: Text.PlainText
                textStyle: "bodyMedium"
                wrapMode: Text.Wrap
            }
            Repeater {
                id: editors
                model: root._fields
                delegate: ColumnLayout {
                    id: field
                    required property var modelData
                    property alias text: editor.text
                    property alias password: editor.password
                    function focusInput() { editor.forceActiveFocus(Qt.OtherFocusReason) }
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    MaterialText {
                        Layout.fillWidth: true
                        text: field.modelData.label
                        textFormat: Text.PlainText
                        textStyle: "bodySmall"
                        wrapMode: Text.Wrap
                    }
                    MaterialTextField {
                        id: editor
                        objectName: "networkCredential_" + field.modelData.key
                        Layout.fillWidth: true
                        enabled: root._current
                        placeholderText: field.modelData.secret ? "Password" : "Value"
                        password: field.modelData.secret
                        trailingIcon: field.modelData.secret ? (password ? "visibility" : "visibility_off") : ""
                        onTrailingClicked: if (field.modelData.secret) password = !password
                        onAccepted: root.submit()
                    }
                }
            }

            MaterialText {
                Layout.fillWidth: true
                visible: root.validationError !== ""
                text: root.validationError
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                colorRole: "error"
                wrapMode: Text.Wrap
            }
            MaterialButton {
                objectName: "networkAuthenticate"
                Layout.fillWidth: true
                text: "Connect"
                enabled: root._current
                onClicked: root.submit()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }
            MaterialButton {
                objectName: "networkAuthCancel"
                Layout.fillWidth: true
                text: "Cancel"
                variant: "text"
                enabled: root._current
                onClicked: root.requestClose()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }
        }
    }
}
