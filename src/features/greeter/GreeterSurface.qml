pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.ui
import qs.components

Item {
    id: root
    required property ShellScreen screen
    property bool isPrimary: false
    property date now: new Date()
    property string _powerDetails: ""
    GreeterAuth {
        id: auth
        active: root.isPrimary
        onClearCredentials: loginForm.clearPassword()
        onFocusRequested: Qt.callLater(() => { if (!powerMenu.opened) loginForm.focusUsername() })
    }
    Surface { anchors.fill: parent; color: GreeterTheme.surfaceDim; outlined: false; radius: Tokens.shape.none }
    Image { id: wallpaper; anchors.fill: parent; source: GreeterConfig.wallpaperPath; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: GreeterConfig.blurWallpaper
        blur: 1.0
        blurMax: Tokens.size.control * 2
        saturation: -0.2
        autoPaddingEnabled: false
    }
    Surface { anchors.fill: parent; color: Qt.alpha(GreeterTheme.scrim, 0.35); outlined: false; radius: Tokens.shape.none }
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.spacing.large
        visible: root.isPrimary && GreeterConfig.showBattery && UPower.displayDevice?.ready === true && UPower.displayDevice.isLaptopBattery
        MaterialIcon { iconName: UPower.onBattery ? "battery_full" : "battery_charging_full"; iconColor: GreeterTheme.scrimForeground }
        MaterialText { text: Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%"; textStyle: "labelLarge"; colorRole: "scrimForeground" }
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        anchors.topMargin: Tokens.size.control + Tokens.spacing.large
        anchors.bottomMargin: Tokens.size.control + Tokens.spacing.large
        contentWidth: width
        contentHeight: Math.max(height, column.implicitHeight)
        visible: !powerMenu.opened
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: column
            width: Math.min(scroll.width, Tokens.size.fieldWidth + Tokens.spacing.extraHuge * 3)
            x: (scroll.width - width) / 2
            y: Math.max(0, (scroll.height - implicitHeight) / 2)
            spacing: Tokens.spacing.medium
            MaterialText {
                Layout.fillWidth: true
                text: Qt.formatTime(root.now, "HH:mm")
                textStyle: "displayLarge"
                colorRole: "scrimForeground"
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Tokens.typography.titleLarge.size
                visible: GreeterConfig.showClock
            }
            MaterialText {
                Layout.fillWidth: true
                text: Qt.formatDate(root.now, "dddd, d MMMM")
                textStyle: "titleMedium"
                colorRole: "scrimForeground"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: GreeterConfig.showDate
            }
            LoginForm {
                id: loginForm
                Layout.fillWidth: true
                visible: root.isPrimary
                authenticating: auth.busy || powerProcess.running
                identityLocked: auth.inProgress || powerProcess.running
                responseRequired: auth.responseRequired
                echoResponse: auth.echoResponse
                prompt: auth.prompt
                errorMessage: auth.errorMessage || GreeterConfig.configError || SessionModel.errorString
                statusMessage: auth.statusMessage
                onEdited: auth.errorMessage = ""
                onCancel: auth.cancel()
                onSubmit: (username, password) => auth.submit(username, password, sessionArgv)
            }
        }
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocus) }
    }
    function revealFocus() {
        const item = root.Window.window?.activeFocusItem
        if (!item || powerMenu.opened) return
        let ancestor = item
        while (ancestor && ancestor !== column) ancestor = ancestor.parent
        if (!ancestor) return
        const top = item.mapToItem(scroll.contentItem, 0, 0).y
        if (top < scroll.contentY) scroll.contentY = top
        else if (top + item.height > scroll.contentY + scroll.height) scroll.contentY = top + item.height - scroll.height
        scroll.contentY = Math.max(0, Math.min(scroll.contentY, scroll.contentHeight - scroll.height))
    }
    Timer { interval: 60000; running: GreeterConfig.showClock || GreeterConfig.showDate; repeat: true; onTriggered: root.now = new Date() }
    IconButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.large
        visible: root.isPrimary && GreeterConfig.showPower
        enabled: !powerMenu.opened
        iconName: "power_settings_new"
        iconColor: GreeterTheme.scrimForeground
        Accessible.name: "Power actions"
        onClicked: powerMenu.show()
    }
    PowerActions {
        id: powerMenu
        visible: root.isPrimary && opened
        anchors.fill: parent
        busy: powerProcess.running
        onClosed: if (root.isPrimary) loginForm.focusUsername()
        onRequested: action => {
            if (!root.isPrimary || powerProcess.running || !["suspend", "reboot", "shutdown"].includes(action)) return
            auth.cancel()
            loginForm.clearPassword()
            root._powerDetails = ""
            powerProcess.command = ["systemctl", action === "shutdown" ? "poweroff" : action]
            powerProcess.running = true
        }
    }
    Process {
        id: powerProcess
        stderr: SplitParser { onRead: line => root._powerDetails = (root._powerDetails + "\n" + line).slice(-2048) }
        onExited: code => {
            if (code === 0) powerMenu.close()
            else { powerMenu.opened = true; powerMenu.errorMessage = root._powerDetails.trim() || "Power action unavailable or blocked (exit " + code + ")."; powerMenu.focusCancel() }
        }
    }
    Component.onCompleted: if (isPrimary) Qt.callLater(loginForm.focusUsername)
}
