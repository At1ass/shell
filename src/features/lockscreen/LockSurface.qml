import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base

Item {
    id: root

    required property ShellScreen screen
    signal unlocked()

    property bool _authFailed: false
    property string _errorMessage: ""
    property string _pendingPassword: ""
    property bool _showPassword: false

    // PAM authentication
    PamContext {
        id: pam
        config: "login"

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root._authFailed = true
                root._errorMessage = "Authentication failed"
                passwordField.text = ""
                shakeAnim.start()
                pam.start()
            }
        }

        onResponseRequiredChanged: {
            if (responseRequired && root._pendingPassword) {
                pam.respond(root._pendingPassword)
                root._pendingPassword = ""
            }
        }
    }

    // --- Background: wallpaper + blur ---
    Image {
        id: wallpaperSource
        anchors.fill: parent
        source: root.screen ? WallpaperService.getWallpaper(root.screen.name) : ""
        fillMode: root.screen ? WallpaperService.getFillMode(root.screen.name) : Image.PreserveAspectCrop
        visible: false
        cache: true

        onStatusChanged: {
            if (status === Image.Error)
                console.warn("LockSurface: wallpaper load failed:", source)
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
        color: Theme.surfaceDim
        visible: wallpaperSource.status !== Image.Ready
    }

    // Scrim overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.scrim, 0.35)
    }

    // --- Center content ---
    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 0
        width: 360

        // Clock
        Text {
            id: clockText
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            font.family: Tokens.typography.fontFamily
            font.pointSize: 72
            font.weight: Font.Light
            font.letterSpacing: -1.5
            color: Theme.scrimForeground
            renderType: Text.NativeRendering
            visible: AppConfig.lockscreenShowClock
        }

        // Date
        MaterialText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraSmall
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
            textStyle: "titleLarge"
            color: Qt.alpha(Theme.scrimForeground, 0.8)
            visible: AppConfig.lockscreenShowClock
        }

        // Weather row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small
            visible: Weather.isFresh

            MaterialIcon {
                iconName: Weather.icon
                fontSize: Tokens.iconSize.medium
                iconColor: Qt.alpha(Theme.scrimForeground, 0.7)
                backgroundColor: "transparent"
            }

            MaterialText {
                text: Math.round(Weather.tempC) + "°"
                textStyle: "titleMedium"
                color: Qt.alpha(Theme.scrimForeground, 0.8)
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                color: Qt.alpha(Theme.scrimForeground, 0.3)
            }

            MaterialText {
                text: Weather.weatherDesc
                textStyle: "bodyMedium"
                color: Qt.alpha(Theme.scrimForeground, 0.6)
            }
        }

        // Spacer
        Item { Layout.preferredHeight: Tokens.spacing.extraLarge + Tokens.spacing.medium }

        // Avatar
        CircleAvatar {
            Layout.alignment: Qt.AlignHCenter
            customSize: 96
            imageSource: "file://" + Quickshell.env("HOME") + "/.face"
            fallbackIcon: "person"
        }

        // Username
        MaterialText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            text: Quickshell.env("USER") || ""
            textStyle: "titleMedium"
            color: Qt.alpha(Theme.scrimForeground, 0.8)
        }

        // Spacer
        Item { Layout.preferredHeight: Tokens.spacing.large }

        // Password input container
        Rectangle {
            id: passwordContainer
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 300
            Layout.preferredHeight: 52
            radius: Tokens.shape.extraLarge
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.5)
            border.color: {
                if (root._authFailed) return Theme.error
                if (passwordField.activeFocus) return Theme.primary
                return Qt.alpha(Theme.scrimForeground, 0.2)
            }
            border.width: passwordField.activeFocus || root._authFailed ? 2 : 1

            Behavior on border.color {
                ColorAnimation { duration: Tokens.motion.duration.short4 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing.medium + 4
                anchors.rightMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small

                // Lock icon
                MaterialIcon {
                    iconName: "lock"
                    fontSize: Tokens.iconSize.medium
                    iconColor: Qt.alpha(Theme.scrimForeground, 0.4)
                    backgroundColor: "transparent"
                }

                // Text input with placeholder
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MaterialText {
                        visible: !passwordField.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        textStyle: "bodyLarge"
                        color: Qt.alpha(Theme.scrimForeground, 0.35)
                    }

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        echoMode: root._showPassword ? TextInput.Normal : TextInput.Password
                        color: Theme.scrimForeground
                        selectedTextColor: Theme.onPrimary
                        selectionColor: Theme.primary
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Tokens.typography.fontFamily
                        font.pointSize: Tokens.typography.bodyLarge.size
                        focus: true
                        clip: true

                        onAccepted: {
                            if (text.length > 0) {
                                root._authFailed = false
                                root._errorMessage = ""
                                if (pam.responseRequired) {
                                    pam.respond(text)
                                } else {
                                    root._pendingPassword = text
                                    if (!pam.active) pam.start()
                                }
                            }
                        }

                        onTextChanged: {
                            if (root._authFailed) {
                                root._authFailed = false
                                root._errorMessage = ""
                            }
                        }
                    }
                }

                // Layout indicator badge
                Rectangle {
                    Layout.preferredWidth: layoutLabel.implicitWidth + Tokens.spacing.medium
                    Layout.preferredHeight: 24
                    radius: Tokens.shape.small
                    color: Qt.alpha(Theme.scrimForeground, 0.1)
                    visible: KeyboardLayoutService.layoutCodes.length > 1

                    MaterialText {
                        id: layoutLabel
                        anchors.centerIn: parent
                        text: KeyboardLayoutService.currentLayoutCode.toUpperCase() || "EN"
                        textStyle: "labelSmall"
                        color: Qt.alpha(Theme.scrimForeground, 0.6)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeyboardLayoutService.switchLayout()
                    }
                }

                // Toggle password visibility
                IconButton {
                    variant: "standard"
                    iconName: root._showPassword ? "visibility_off" : "visibility"
                    iconSize: 18
                    containerSize: 32
                    touchTargetSize: 36
                    iconColor: Qt.alpha(Theme.scrimForeground, 0.5)

                    onClicked: {
                        root._showPassword = !root._showPassword
                        passwordField.forceActiveFocus()
                    }
                }
            }
        }

        // Error message
        MaterialText {
            id: errorText
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            text: root._errorMessage
            textStyle: "labelMedium"
            color: Theme.error
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
        running: true
        repeat: true
        onTriggered: {
            clockText.text = Qt.formatTime(new Date(), "HH:mm")
        }
    }

    // Start PAM on surface appear
    Component.onCompleted: {
        pam.start()
        passwordField.forceActiveFocus()
    }

    Component.onDestruction: {
        if (pam.active) pam.abort()
    }
}
