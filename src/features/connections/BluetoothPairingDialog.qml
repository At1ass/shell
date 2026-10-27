pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

// This dialog shares the Connections window's grab; all decisions carry the
// request token so a delayed key/click cannot confirm a replacement request.
Dialog {
    id: root
    property string requestToken: ""
    property string requestKind: ""
    property string deviceName: ""
    property string deviceAddress: ""
    property string code: ""
    property string serviceUuid: ""
    property int entered: 0
    property string validationError: ""
    signal answered(string token, string value)
    signal rejected(string token)

    property string _shownToken: ""
    property string _kind: ""
    property string _name: ""
    property string _address: ""
    property string _code: ""
    property string _uuid: ""
    readonly property bool _current: requestToken !== "" && requestToken === _shownToken
    readonly property bool _input: _kind === "pin" || _kind === "passkey"
    readonly property bool _display: _kind === "display-pin" || _kind === "display-passkey"
    readonly property int desiredHeight: dialogHeight + Tokens.spacing.large * 2
    dialogWidth: width - Tokens.spacing.small * 2
    dialogHeight: column.implicitHeight + Tokens.spacing.medium * 2

    onRequestTokenChanged: Qt.callLater(root._syncRequest)
    function _syncRequest() {
        if (requestToken === "") {
            input.text = ""
            if (visible) close()
            return
        }
        if (_shownToken === requestToken && visible && opacity > 0) return
        _shownToken = requestToken
        _kind = requestKind; _name = deviceName; _address = deviceAddress
        _code = code; _uuid = serviceUuid
        input.text = ""
        if (!visible || opacity === 0) open()
        const token = _shownToken
        Qt.callLater(() => {
            if (!root._current || root._shownToken !== token) return
            if (root._input) input.forceActiveFocus(Qt.OtherFocusReason)
            else cancel.forceActiveFocus(Qt.OtherFocusReason)
        })
    }
    function requestClose() { if (_current) rejected(_shownToken) }
    function submit() {
        if (!_current || _display || (_input && !input.inputItem.acceptableInput)) return
        answered(_shownToken, _input ? input.text : "")
    }
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.medium
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            MaterialText {
                Layout.fillWidth: true
                text: "Pair with " + root._name
                textFormat: Text.PlainText
                textStyle: "titleSmall"
                wrapMode: Text.Wrap
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root._address !== ""
                text: root._address
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
            }
            MaterialText {
                Layout.fillWidth: true
                text: root._kind === "confirm" ? "Confirm that this code matches the code on your device."
                    : root._display ? "Enter this code on your device, then press Enter there."
                    : root._kind === "pin" ? "Enter the PIN provided by your device."
                    : root._kind === "passkey" ? "Enter the numeric passkey shown on your device."
                    : root._kind === "service" ? "Allow this service for the device you are pairing?"
                    : "Allow pairing with this device?"
                textStyle: "bodyMedium"
                wrapMode: Text.WordWrap
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root._code !== ""
                text: root._code
                textFormat: Text.PlainText
                textStyle: "headlineMedium"
                horizontalAlignment: Text.AlignHCenter
                font.family: Tokens.typography.monoFamily
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root._kind === "display-passkey"
                text: "Entered: " + root.entered + " / 6"
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root._uuid !== ""
                text: root._uuid
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                wrapMode: Text.WrapAnywhere
            }
            MaterialTextField {
                id: input
                objectName: "pairingInput"
                Layout.fillWidth: true
                visible: root._input
                enabled: root._current
                placeholderText: root._kind === "pin" ? "PIN" : "Passkey"
                validator: RegularExpressionValidator { regularExpression: root._kind === "pin" ? /^[\x20-\x7e]{1,16}$/ : /^[0-9]{1,6}$/ }
                onAccepted: root.submit()
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root.validationError !== ""
                text: root.validationError
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                colorRole: "error"
                wrapMode: Text.WordWrap
            }
            MaterialButton {
                objectName: "pairingConfirm"
                Layout.fillWidth: true
                visible: !root._display
                enabled: root._current && (!root._input || input.inputItem.acceptableInput)
                text: root._kind === "confirm" ? "Codes match" : root._input ? "Pair" : "Allow"
                onClicked: root.submit()
            }
            MaterialButton {
                id: cancel
                objectName: "pairingCancel"
                Layout.fillWidth: true
                enabled: root._current
                text: "Cancel"
                variant: "text"
                onClicked: root.requestClose()
            }
        }
    }
}
