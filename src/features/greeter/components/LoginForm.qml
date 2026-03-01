import QtQuick
import QtQuick.Layouts
import qs.config
import qs.ui

ColumnLayout {
    id: root

    property bool authFailed: false
    property string errorMessage: ""
    property string statusMessage: ""
    property bool authenticating: false

    signal submit(string username, string password)

    function clearPassword() {
        passwordField.text = ""
    }

    function focusUsername() {
        if (usernameField.text)
            passwordField.forceActiveFocus()
        else
            usernameField.forceActiveFocus()
    }

    spacing: 0
    width: 300

    // Avatar
    CircleAvatar {
        Layout.alignment: Qt.AlignHCenter
        customSize: 96
        imageSource: {
            if (UserModel.count === 1)
                return UserModel.users[0].facePath
            // Try to find matching user
            for (let i = 0; i < UserModel.users.length; i++) {
                if (UserModel.users[i].username === usernameField.text)
                    return UserModel.users[i].facePath
            }
            return ""
        }
        fallbackIcon: "person"
    }

    Item { Layout.preferredHeight: Tokens.spacing.large }

    // Username input
    Rectangle {
        id: usernameContainer
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 300
        Layout.preferredHeight: 52
        radius: Tokens.shape.extraLarge
        color: Qt.alpha(GreeterTheme.surfaceContainerHigh, 0.5)
        border.color: {
            if (usernameField.activeFocus) return GreeterTheme.primary
            return Qt.alpha(GreeterTheme.scrimForeground, 0.2)
        }
        border.width: usernameField.activeFocus ? 2 : 1

        Behavior on border.color {
            ColorAnimation { duration: Tokens.motion.duration.short4 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.medium + 4
            anchors.rightMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            MaterialIcon {
                iconName: "person"
                fontSize: Tokens.iconSize.medium
                iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.4)
                backgroundColor: "transparent"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialText {
                    visible: !usernameField.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Username"
                    textStyle: "bodyLarge"
                    color: Qt.alpha(GreeterTheme.scrimForeground, 0.35)
                }

                TextInput {
                    id: usernameField
                    anchors.fill: parent
                    color: GreeterTheme.scrimForeground
                    selectedTextColor: GreeterTheme.onPrimary
                    selectionColor: GreeterTheme.primary
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.typography.fontFamily
                    font.pointSize: Tokens.typography.bodyLarge.size
                    clip: true
                    enabled: !root.authenticating

                    onAccepted: {
                        passwordField.forceActiveFocus()
                    }

                    Keys.onTabPressed: {
                        passwordField.forceActiveFocus()
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: Tokens.spacing.medium }

    // Password input
    Rectangle {
        id: passwordContainer
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 300
        Layout.preferredHeight: 52
        radius: Tokens.shape.extraLarge
        color: Qt.alpha(GreeterTheme.surfaceContainerHigh, 0.5)
        border.color: {
            if (root.authFailed) return GreeterTheme.error
            if (passwordField.activeFocus) return GreeterTheme.primary
            return Qt.alpha(GreeterTheme.scrimForeground, 0.2)
        }
        border.width: passwordField.activeFocus || root.authFailed ? 2 : 1

        Behavior on border.color {
            ColorAnimation { duration: Tokens.motion.duration.short4 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.medium + 4
            anchors.rightMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                iconName: "lock"
                fontSize: Tokens.iconSize.medium
                iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.4)
                backgroundColor: "transparent"
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialText {
                    visible: !passwordField.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Password"
                    textStyle: "bodyLarge"
                    color: Qt.alpha(GreeterTheme.scrimForeground, 0.35)
                }

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    echoMode: showPassword ? TextInput.Normal : TextInput.Password
                    color: GreeterTheme.scrimForeground
                    selectedTextColor: GreeterTheme.onPrimary
                    selectionColor: GreeterTheme.primary
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Tokens.typography.fontFamily
                    font.pointSize: Tokens.typography.bodyLarge.size
                    clip: true
                    enabled: !root.authenticating

                    property bool showPassword: false

                    onAccepted: {
                        if (usernameField.text && text.length > 0) {
                            root.submit(usernameField.text, text)
                        }
                    }

                    onTextChanged: {
                        if (root.authFailed) {
                            root.authFailed = false
                            root.errorMessage = ""
                        }
                    }

                    Keys.onTabPressed: {
                        usernameField.forceActiveFocus()
                    }
                }
            }

            IconButton {
                variant: "standard"
                iconName: passwordField.showPassword ? "visibility_off" : "visibility"
                iconSize: 18
                containerSize: 32
                touchTargetSize: 36
                iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.5)

                onClicked: {
                    passwordField.showPassword = !passwordField.showPassword
                    passwordField.forceActiveFocus()
                }
            }
        }
    }

    Item { Layout.preferredHeight: Tokens.spacing.medium }

    // Session selector
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 300
        Layout.preferredHeight: 40
        radius: Tokens.shape.extraLarge
        color: Qt.alpha(GreeterTheme.surfaceContainerHigh, 0.3)
        visible: SessionModel.sessions.length > 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            spacing: 0

            IconButton {
                variant: "standard"
                iconName: "chevron_left"
                iconSize: 18
                containerSize: 32
                touchTargetSize: 36
                iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.6)
                enabled: SessionModel.sessions.length > 1

                onClicked: SessionModel.selectPrevious()
            }

            MaterialText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: SessionModel.currentSession ? SessionModel.currentSession.name : "No sessions"
                textStyle: "bodyMedium"
                color: Qt.alpha(GreeterTheme.scrimForeground, 0.8)
                elide: Text.ElideRight
            }

            IconButton {
                variant: "standard"
                iconName: "chevron_right"
                iconSize: 18
                containerSize: 32
                touchTargetSize: 36
                iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.6)
                enabled: SessionModel.sessions.length > 1

                onClicked: SessionModel.selectNext()
            }
        }
    }

    Item { Layout.preferredHeight: Tokens.spacing.large }

    // Login button
    MaterialButton {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 300
        Layout.preferredHeight: 48
        text: root.authenticating ? "Logging in..." : "Login"
        variant: "filled"
        enabled: !root.authenticating && usernameField.text.length > 0 && passwordField.text.length > 0

        onClicked: {
            root.submit(usernameField.text, passwordField.text)
        }
    }

    // Status message
    MaterialText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.small
        text: root.statusMessage
        textStyle: "bodySmall"
        color: Qt.alpha(GreeterTheme.scrimForeground, 0.6)
        visible: root.statusMessage !== ""
    }

    // Auto-fill username if single user or defaultUser configured
    Component.onCompleted: {
        if (GreeterConfig.defaultUser) {
            usernameField.text = GreeterConfig.defaultUser
        }

        // Watch for UserModel to finish loading
        _checkAutoFill()
    }

    function _checkAutoFill() {
        if (UserModel.count === 1 && !usernameField.text) {
            usernameField.text = UserModel.users[0].username
        }
    }

    Connections {
        target: UserModel
        function onUsersChanged() {
            root._checkAutoFill()
        }
    }
}
