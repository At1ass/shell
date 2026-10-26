pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.ui

ColumnLayout {
    id: root
    property bool authenticating: false
    property bool identityLocked: false
    property bool responseRequired: false
    property bool echoResponse: false
    property string prompt: "Password"
    property string errorMessage: ""
    property string statusMessage: ""
    property bool manualUser: false
    property bool choosingUser: false
    property bool _touched: false
    property bool _showPassword: false
    readonly property string username: manualUser ? usernameField.text.trim() : UserModel.users[userChoice.currentIndex]?.username ?? ""
    readonly property list<string> sessionArgv: SessionModel.currentSession?.argv ?? []
    property alias password: passwordField.text
    signal submit(string username, string password)
    signal cancel()
    signal edited()
    spacing: Tokens.spacing.small

    function clearPassword() { passwordField.text = ""; root._showPassword = false }
    function focusUsername() {
        if (!visible) return
        if (manualUser && !username) usernameField.inputItem.forceActiveFocus()
        else passwordField.inputItem.forceActiveFocus()
    }
    function autoFill() {
        if (_touched || !GreeterConfig.ready) return
        const index = UserModel.indexOfUser(GreeterConfig.defaultUser)
        if (GreeterConfig.defaultUser && index < 0) {
            manualUser = true
            usernameField.text = GreeterConfig.defaultUser
        } else {
            manualUser = UserModel.count === 0
            userChoice.currentIndex = index >= 0 ? index : 0
        }
        Qt.callLater(focusUsername)
    }
    function submitResponse() {
        if (!authenticating && username && (responseRequired || passwordField.text.length > 0)) submit(username, passwordField.text)
    }
    MaterialText {
        Layout.fillWidth: true
        visible: !root.manualUser
        text: UserModel.users[userChoice.currentIndex]?.displayName || root.username
        textStyle: "titleMedium"
        colorRole: "scrimForeground"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    MaterialComboBox {
        id: userChoice
        objectName: "greeterUserChoice"
        Layout.fillWidth: true
        visible: root.choosingUser && !root.identityLocked
        label: "User"
        model: Array.from(UserModel.names).concat(["Other user…"])
        onCurrentIndexChanged: {
            root.clearPassword()
            if (currentIndex === UserModel.count && root.choosingUser) {
                root._touched = true
                root.manualUser = true
                root.choosingUser = false
                usernameField.text = ""
                Qt.callLater(root.focusUsername)
            } else if (currentIndex < UserModel.count && root.choosingUser) {
                root._touched = true
                root.manualUser = false
                root.choosingUser = false
                Qt.callLater(root.focusUsername)
            }
        }
    }
    MaterialTextField {
        id: usernameField
        objectName: "greeterUsername"
        Layout.fillWidth: true
        visible: root.manualUser
        enabled: !root.identityLocked
        placeholderText: "Username"
        leadingIcon: "person"
        inputItem.Accessible.name: "Username"
        onAccepted: passwordField.inputItem.forceActiveFocus()
        onTextEdited: if (inputItem.activeFocus) { root._touched = true; root.clearPassword() }
    }
    MaterialTextField {
        id: passwordField
        objectName: "greeterPassword"
        Layout.fillWidth: true
        enabled: !root.authenticating
        placeholderText: root.prompt
        leadingIcon: "lock"
        password: (!root.responseRequired || !root.echoResponse) && !root._showPassword
        trailingIcon: password ? "visibility" : "visibility_off"
        inputItem.Accessible.name: root.prompt
        inputItem.inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        onTrailingClicked: { root._showPassword = !root._showPassword; inputItem.forceActiveFocus() }
        onAccepted: root.submitResponse()
        onTextEdited: root.edited()
        trailingContent: [
            MaterialButton {
                variant: "text"
                text: KeyboardLayoutService.currentLayoutCode.toUpperCase() || "EN"
                implicitWidth: Math.max(Tokens.touchTarget.minimum, implicitContentWidth + Tokens.spacing.small * 2)
                leftPadding: Tokens.spacing.small
                rightPadding: Tokens.spacing.small
                enabled: KeyboardLayoutService.layoutCodes.length > 1
                onClicked: { KeyboardLayoutService.switchLayout(); root.focusUsername() }
            },
            IconButton {
                objectName: "greeterSubmit"
                iconName: "arrow_forward"
                Accessible.name: "Log in"
                enabled: !root.authenticating && root.username !== "" && (root.responseRequired || passwordField.text.length > 0)
                onClicked: root.submitResponse()
            }
        ]
    }
    MaterialText {
        Layout.fillWidth: true
        text: root.prompt
        textStyle: "bodySmall"
        colorRole: "scrimForeground"
        visible: root.responseRequired
        wrapMode: Text.WordWrap
    }
    MaterialText { visible: KeyboardLayoutService.capsLockEnabled; text: "Caps Lock"; textStyle: "labelMedium"; colorRole: "error" }
    MaterialButton {
        objectName: "greeterChangeUser"
        Layout.alignment: Qt.AlignHCenter
        text: "Change user"
        variant: "text"
        visible: !root.identityLocked
        onClicked: {
            root._touched = true
            root.clearPassword()
            if (UserModel.count === 0) { root.manualUser = true; usernameField.inputItem.forceActiveFocus() }
            else { root.choosingUser = !root.choosingUser; if (root.choosingUser) {userChoice.forceActiveFocus();userChoice.open = true} }
        }
    }
    MaterialComboBox {
        objectName: "greeterSessionChoice"
        Layout.fillWidth: true
        visible: SessionModel.sessions.length > 1
        enabled: !root.identityLocked
        label: "Session"
        model: SessionModel.names
        currentIndex: SessionModel.selectedIndex
        onCurrentIndexChanged: if (visible && !root.identityLocked) SessionModel.selectedIndex = currentIndex
    }
    MaterialText {
        Layout.fillWidth: true
        visible: SessionModel.ready && SessionModel.sessions.length === 0
        text: "No desktop sessions found"
        textStyle: "bodySmall"
        colorRole: "error"
        wrapMode: Text.WordWrap
    }
    MaterialButton {
        objectName: "greeterCancelAuth"
        Layout.alignment: Qt.AlignHCenter
        visible: root.identityLocked
        text: "Cancel"
        variant: "text"
        onClicked: root.cancel()
    }
    MaterialText {
        Layout.fillWidth: true
        text: root.errorMessage || root.statusMessage
        textStyle: "bodySmall"
        colorRole: root.errorMessage ? "error" : "scrimForeground"
        wrapMode: Text.WordWrap
        Layout.minimumHeight: Tokens.typography.bodySmall.lineHeight * 2
        Accessible.role: Accessible.AlertMessage
    }
    Connections { target: UserModel; function onUsersChanged() { root.autoFill() } }
    Connections { target: GreeterConfig; function onReadyChanged() { root.autoFill() } }
    Component.onCompleted: { KeyboardLayoutService.addLockStateWatcher(); autoFill() }
    Component.onDestruction: KeyboardLayoutService.removeLockStateWatcher()
}
