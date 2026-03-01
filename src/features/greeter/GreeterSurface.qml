import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.config
import qs.ui
import qs.components

Item {
    id: root

    required property ShellScreen screen
    property bool isPrimary: false

    property bool _authFailed: false
    property string _errorMessage: ""
    property string _statusMessage: ""
    property bool _authenticating: false

    // --- Background: wallpaper + blur ---
    Image {
        id: wallpaperSource
        anchors.fill: parent
        source: GreeterConfig.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: true

        onStatusChanged: {
            if (status === Image.Error)
                console.warn("GreeterSurface: wallpaper load failed:", source)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaperSource
        blurEnabled: true
        blur: 1.0
        blurMax: 80
        saturation: -0.2
        autoPaddingEnabled: false
    }

    // Fallback if wallpaper not loaded
    Rectangle {
        anchors.fill: parent
        color: GreeterTheme.surfaceDim
        visible: wallpaperSource.status !== Image.Ready
    }

    // Scrim overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(GreeterTheme.scrim, 0.35)
    }

    // --- Center content (only on primary screen) ---
    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 0
        width: 360
        visible: root.isPrimary

        // Clock
        Text {
            id: clockText
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            font.family: Tokens.typography.fontFamily
            font.pointSize: 72
            font.weight: Font.Light
            font.letterSpacing: -1.5
            color: GreeterTheme.scrimForeground
            renderType: Text.NativeRendering
            visible: GreeterConfig.showClock
        }

        // Date
        MaterialText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraSmall
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
            textStyle: "titleLarge"
            color: Qt.alpha(GreeterTheme.scrimForeground, 0.8)
            visible: GreeterConfig.showClock
        }

        // Spacer
        Item { Layout.preferredHeight: Tokens.spacing.extraLarge + Tokens.spacing.medium }

        // Login form
        LoginForm {
            id: loginForm
            Layout.alignment: Qt.AlignHCenter
            authFailed: root._authFailed
            errorMessage: root._errorMessage
            statusMessage: root._statusMessage
            authenticating: root._authenticating

            onSubmit: (username, password) => {
                root._authFailed = false
                root._errorMessage = ""
                root._statusMessage = "Authenticating..."
                root._authenticating = true
                root._pendingPassword = password
                Greetd.createSession(username)
            }
        }

        // Error message
        MaterialText {
            id: errorText
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            text: root._errorMessage
            textStyle: "labelMedium"
            color: GreeterTheme.error
            opacity: root._errorMessage ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Tokens.motion.duration.short4 }
            }
        }
    }

    // Shake animation on auth failure
    SequentialAnimation {
        id: shakeAnim
        property int _offset: 12
        NumberAnimation { target: contentColumn; property: "anchors.horizontalCenterOffset"; to: shakeAnim._offset; duration: 50 }
        NumberAnimation { target: contentColumn; property: "anchors.horizontalCenterOffset"; to: -shakeAnim._offset; duration: 50 }
        NumberAnimation { target: contentColumn; property: "anchors.horizontalCenterOffset"; to: shakeAnim._offset / 2; duration: 50 }
        NumberAnimation { target: contentColumn; property: "anchors.horizontalCenterOffset"; to: -shakeAnim._offset / 2; duration: 50 }
        NumberAnimation { target: contentColumn; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
    }

    // Timer for clock updates
    Timer {
        interval: 1000
        running: root.isPrimary && GreeterConfig.showClock
        repeat: true
        onTriggered: {
            clockText.text = Qt.formatTime(new Date(), "HH:mm")
        }
    }

    // --- Greetd IPC wiring ---
    property string _pendingPassword: ""

    Connections {
        target: Greetd
        enabled: root.isPrimary

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (error) {
                root._errorMessage = message || "Authentication error"
                root._authenticating = false
                return
            }

            if (responseRequired) {
                if (root._pendingPassword) {
                    Greetd.respond(root._pendingPassword)
                    root._pendingPassword = ""
                } else {
                    root._statusMessage = message || "Enter credentials"
                    root._authenticating = false
                }
            } else {
                root._statusMessage = message || ""
            }
        }

        function onReadyToLaunch() {
            root._statusMessage = "Starting session..."
            let session = SessionModel.currentSession
            if (session) {
                let args = session.exec.split(" ")
                Greetd.launch(args, [], true)
            } else {
                root._authFailed = true
                root._errorMessage = "No session selected"
                root._authenticating = false
            }
        }

        function onAuthFailure(message) {
            root._authFailed = true
            root._errorMessage = message || "Authentication failed"
            root._statusMessage = ""
            root._authenticating = false
            root._pendingPassword = ""
            loginForm.clearPassword()
            shakeAnim.start()
        }

        function onError(error) {
            root._authFailed = true
            root._errorMessage = error || "Greetd error"
            root._statusMessage = ""
            root._authenticating = false
            root._pendingPassword = ""
            loginForm.clearPassword()
            shakeAnim.start()
        }
    }

    // --- Power actions (bottom of screen) ---
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Tokens.spacing.extraLarge
        spacing: Tokens.spacing.large
        visible: root.isPrimary

        Repeater {
            model: [
                { icon: "power_settings_new", label: "Shutdown", cmd: ["systemctl", "poweroff"] },
                { icon: "restart_alt",        label: "Reboot",   cmd: ["systemctl", "reboot"] },
                { icon: "dark_mode",          label: "Suspend",  cmd: ["systemctl", "suspend"] }
            ]

            delegate: Column {
                required property var modelData
                spacing: Tokens.spacing.extraSmall

                Rectangle {
                    id: powerBtn
                    width: 64
                    height: 64
                    radius: Tokens.shape.extraLarge
                    color: powerMouse.containsMouse
                        ? Qt.alpha(GreeterTheme.surfaceContainerHigh, 0.7)
                        : Qt.alpha(GreeterTheme.surfaceContainerHigh, 0.4)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: modelData.icon
                        fontSize: Tokens.iconSize.large
                        iconColor: Qt.alpha(GreeterTheme.scrimForeground, 0.8)
                        backgroundColor: "transparent"
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerProc.command = modelData.cmd
                            powerProc.running = true
                        }
                    }
                }

                MaterialText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    textStyle: "labelSmall"
                    color: Qt.alpha(GreeterTheme.scrimForeground, 0.6)
                }
            }
        }
    }

    Process {
        id: powerProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("GreeterSurface: power action failed with code", exitCode)
        }
    }

    Component.onCompleted: {
        if (root.isPrimary) {
            loginForm.focusUsername()
        }
    }
}
