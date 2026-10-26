import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers

Item {
    id: root
    required property ShellScreen screen
    property bool formActive: !!screen && screen.name === (Quickshell.screens.find(s => s?.name === GlobalStates.lockscreenScreenName)?.name ?? Quickshell.screens[0]?.name ?? "")
    signal unlocked()
    property bool _ready: false
    property string _powerDetails: ""
    property bool _powerPending: false
    property string _pendingPassword: ""
    property string _errorMessage: ""

    function startAuthentication() {
        if (_ready && formActive && !_powerPending && !pam.active && !pam.start()) pamRetryTimer.start()
    }
    function submit(password) {
        if (!_ready || !formActive || !password) return
        _errorMessage = ""
        content.clearPassword()
        if (pam.responseRequired) pam.respond(password)
        else { _pendingPassword = password; startAuthentication() }
    }
    TapHandler {
        enabled: !root.formActive && root.screen !== null
        onTapped: GlobalStates.lockscreenScreenName = root.screen.name
    }
    PamContext {
        id: pam
        config: "login"
        onCompleted: result => {
            root._pendingPassword = ""
            content.clearPassword()
            if (!root._ready || !root.formActive || root._powerPending) return
            if (result === PamResult.Success) { root.unlocked(); return }
            root._errorMessage = result === PamResult.MaxTries ? "Too many attempts" : "Authentication failed"
            if (result === PamResult.Error) pamRetryTimer.start()
            else root.startAuthentication()
            content.focusPassword()
        }
        onResponseRequiredChanged: {
            if (responseRequired && root._pendingPassword) {
                const password = root._pendingPassword
                root._pendingPassword = ""
                pam.respond(password)
            }
        }
    }
    Image {
        id: wallpaperSource
        anchors.fill: parent
        source: root.screen ? WallpaperManager.getWallpaper(root.screen.name) : ""
        fillMode: root.screen ? WallpaperManager.getFillMode(root.screen.name) : Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    Surface { anchors.fill: parent; radius: Tokens.shape.none; color: Theme.surfaceDim; outlined: false }
    MultiEffect {
        anchors.fill: parent
        source: wallpaperSource
        blurEnabled: AppConfig.lockscreenBlurWallpaper
        blur: 1.0
        blurMax: Tokens.size.control * 2
        saturation: -0.2
        autoPaddingEnabled: false
    }
    Surface { anchors.fill: parent; radius: Tokens.shape.none; color: Qt.alpha(Theme.scrim, 0.35); outlined: false }
    LockContent {
        id: content
        anchors.fill: parent
        formActive: root.formActive
        username: Quickshell.env("USER") || ""
        now: DateTime.clock.date
        layoutCode: KeyboardLayoutService.currentLayoutCode
        multipleLayouts: KeyboardLayoutService.layoutCodes.length > 1
        capsLock: KeyboardLayoutService.capsLockEnabled
        errorMessage: root._errorMessage
        powerBusy: powerProcess.running
        mediaAvailable: MprisController.activePlayer !== null
        playing: MprisController.isPlaying
        trackTitle: MprisController.activeTrack?.title ?? ""
        trackArtist: MprisController.activeTrack?.artist ?? ""
        trackArt: MprisController.activeTrack?.artUrl ?? ""
        canPrevious: MprisController.canGoPrevious
        canNext: MprisController.canGoNext
        canToggle: MprisController.canTogglePlaying
        batteryAvailable: UPower.displayDevice?.ready === true && UPower.displayDevice.isLaptopBattery
        batteryPercent: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
        charging: UPower.displayDevice?.state === UPowerDeviceState.Charging || UPower.displayDevice?.state === UPowerDeviceState.PendingCharge
        networkIcon: NetworkService.connectionIcon
        networkStatus: NetworkService.wiredConnected ? "Ethernet connected" : NetworkService.currentNetwork !== "" ? "Wi-Fi connected" : "Disconnected"
        weatherAvailable: Weather.isFresh
        weatherText: Math.round(Weather.tempC) + "° · " + Weather.weatherDesc
        onSubmitted: password => root.submit(password)
        onEdited: root._errorMessage = ""
        onSwitchLayout: KeyboardLayoutService.switchLayout()
        onPrevious: MprisController.previous()
        onNext: MprisController.next()
        onTogglePlaying: MprisController.togglePlaying()
        onPowerRequested: action => {
            if (!root.formActive || powerProcess.running || !["suspend", "reboot", "shutdown"].includes(action)) return
            root._powerPending = true
            root._pendingPassword = ""
            pamRetryTimer.stop()
            if (pam.active) pam.abort()
            root._powerDetails = ""
            content.powerError = ""
            powerProcess.command = ["systemctl", action === "shutdown" ? "poweroff" : action]
            powerProcess.running = true
        }
    }
    Process {
        id: powerProcess
        stderr: SplitParser { onRead: line => root._powerDetails = (root._powerDetails + "\n" + line).slice(-2048) }
        onExited: exitCode => {
            root._powerPending = false
            if (exitCode !== 0) {
                content.powerOpen = root.formActive
                content.powerError = root._powerDetails.trim() || "Power action unavailable or blocked (exit " + exitCode + ")."
            }
            else content.closePower()
            root.startAuthentication()
        }
    }
    Timer { id: pamRetryTimer; interval: 2000; onTriggered: root.startAuthentication() }
    property bool _watchingKeyboard: false
    function updateKeyboardWatcher() {
        if (formActive === _watchingKeyboard) return
        _watchingKeyboard = formActive
        if (_watchingKeyboard) KeyboardLayoutService.addLockStateWatcher()
        else KeyboardLayoutService.removeLockStateWatcher()
    }
    onFormActiveChanged: { if (!_ready) return; updateKeyboardWatcher(); if (formActive) { startAuthentication(); Qt.callLater(content.focusPassword) } else { pamRetryTimer.stop(); _pendingPassword = ""; if (pam.active) pam.abort() } }
    Component.onCompleted: { _ready = true; updateKeyboardWatcher(); startAuthentication(); Qt.callLater(content.focusPassword) }
    Component.onDestruction: {
        _ready = false
        _pendingPassword = ""
        if (_watchingKeyboard) KeyboardLayoutService.removeLockStateWatcher()
        if (pam.active) pam.abort()
    }
}
