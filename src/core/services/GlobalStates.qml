import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.core.config

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    // Главные панели
    property bool controlPanelOpen: false
    property bool dashboardOpen: false
    property int  dashboardOpenIndex: 0
    property bool notificationCenterOpen: false
    property bool showDateSelector: false
    property bool darkMode: true
    property bool inhibit: false
    property bool launcherOpen: false
    property bool controlPanelLeftOpen: false

    // Screenshot overlay
    property bool screenshotOverlayActive: false

    // Lockscreen & Power Menu
    property bool lockscreenActive: false
    property bool powerMenuOpen: false

    // Cheatsheet
    property bool cheatsheetOpen: false

    // OSD элементы (для будущего расширения)
    property bool osdVolumeOpen: false
    property bool osdBrightnessOpen: false

    // Утилиты для закрытия всех панелей
    function closeAllPanels() {
        controlPanelOpen = false
        dashboardOpen = false
        launcherOpen = false
        notificationCenterOpen = false
        cheatsheetOpen = false
    }

    // Открыть Dashboard на конкретной вкладке
    // tabIndex: 0 = Quick, 1 = Media, 2 = Calendar, 3 = System
    function openDashboardTab(tabIndex) {
        dashboardOpenIndex = tabIndex
        dashboardOpen = true
    }

    // Handle widget click actions from bar configuration
    function handleClickAction(action) {
        if (!action)
            return

        switch (action) {
            case "dashboard-quick":
                openDashboardTab(0)
                return
            case "dashboard-weather":
                openDashboardTab(1)
                return
            case "dashboard-calendar":
                openDashboardTab(2)
                return
            case "dashboard-system":
                openDashboardTab(3)
                return
            case "notification-center":
                notificationCenterOpen = !notificationCenterOpen
                return
            case "launcher":
                launcherOpen = !launcherOpen
                return
            case "control-panel":
                controlPanelOpen = !controlPanelOpen
                return
            default:
                console.warn("GlobalStates: unknown clickAction:", action)
        }
    }

    function closeAllOSD() {
        osdVolumeOpen = false
        osdBrightnessOpen = false
    }

    // Lock/Unlock
    function lockSession() {
        closeAllPanels()
        powerMenuOpen = false
        lockscreenActive = true
    }

    function unlockSession() {
        lockscreenActive = false
    }

    // Power actions
    Process { id: powerProc }

    function executePowerAction(action) {
        powerMenuOpen = false
        switch (action) {
            case "lock":     lockSession(); return
            case "suspend":  powerProc.command = ["systemctl", "suspend"]; break
            case "reboot":   powerProc.command = ["systemctl", "reboot"]; break
            case "shutdown": powerProc.command = ["systemctl", "poweroff"]; break
            case "logout":   powerProc.command = ["hyprctl", "dispatch", "exit"]; break
            default: return
        }
        powerProc.running = true
    }

    // DBus lock signal listener (loginctl lock-session)
    Process {
        id: lockListenerProc
        command: ["gdbus", "monitor", "--system",
                  "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1/session/auto"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Lock")) root.lockSession()
            }
        }
    }

    // Screenshot
    property string _grimGeometry: ""
    property bool _useSwappy: false

    Process {
        id: screenshotRegionProc
        command: ["sh", "-c", `sleep 0.2 && grim -g "${root._grimGeometry}" - | wl-copy`]
        onExited: (exitCode) => {
            if (exitCode === 0) ToastService.success("Screenshot copied to clipboard")
            else ToastService.error("Screenshot failed (grim exited " + exitCode + ")")
        }
    }

    Process {
        id: screenshotSwappyProc
        command: ["sh", "-c", `sleep 0.2 && grim -g "${root._grimGeometry}" - | swappy -f -`]
        onExited: (exitCode) => {
            if (exitCode !== 0) ToastService.error("Screenshot annotation failed")
        }
    }

    function takeScreenshot() {
        root.dashboardOpen = false
        root._useSwappy = false
        root.screenshotOverlayActive = true
    }

    function takeScreenshotSwappy() {
        root.dashboardOpen = false
        root._useSwappy = true
        root.screenshotOverlayActive = true
    }

    function captureRegion(geometry) {
        root._grimGeometry = geometry
        root.screenshotOverlayActive = false
        if (root._useSwappy) {
            root._useSwappy = false
            screenshotSwappyProc.running = true
        } else {
            screenshotRegionProc.running = true
        }
    }


    // Автозакрытие панелей при открытии другой
    onControlPanelOpenChanged: {
        if (controlPanelOpen) {
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            controlPanelOpen = false
            launcherOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onNotificationCenterOpenChanged: {
        if (notificationCenterOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            launcherOpen = false
            cheatsheetOpen = false
        }
    }

    onPowerMenuOpenChanged: {
        if (powerMenuOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onCheatsheetOpenChanged: {
        if (cheatsheetOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
        }
    }

    // Глобальные хоткеи
    GlobalShortcut {
        name: "controlPanelToggle"
        description: "Toggle control panel"

        onPressed: {
            root.controlPanelOpen = !root.controlPanelOpen
        }
    }

    GlobalShortcut {
        name: "closeAllPanels"
        description: "Close all open panels"

        onPressed: {
            root.closeAllPanels()
        }
    }

    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggle launcher"

        onPressed: {
            root.launcherOpen = !root.launcherOpen
        }
    }

    GlobalShortcut {
        name: "screenshot"
        description: "Take a screenshot (area)"

        onPressed: {
            root.takeScreenshot()
        }
    }

    GlobalShortcut {
        name: "screenshotSwappy"
        description: "Take annotated screenshot (swappy)"

        onPressed: {
            root.takeScreenshotSwappy()
        }
    }

    GlobalShortcut {
        name: "powerMenuToggle"
        description: "Toggle power menu"

        onPressed: {
            root.powerMenuOpen = !root.powerMenuOpen
        }
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle cheatsheet overlay"

        onPressed: {
            root.cheatsheetOpen = !root.cheatsheetOpen
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // GAMING MODE
    // ═══════════════════════════════════════════════════════════════

    property bool gamingModeActive: false
    property var _savedHyprState: ({})
    property bool _gamingModeRestored: false

    Connections {
        target: AppConfig
        function onStateReadyChanged() { root._tryRestoreGamingMode() }
        function onReadyChanged()      { root._tryRestoreGamingMode() }
    }

    function _tryRestoreGamingMode() {
        if (!AppConfig.stateReady || !AppConfig.ready) return
        if (root._gamingModeRestored) return
        root._gamingModeRestored = true

        const gmState = AppConfig.stateData?.gamingMode
        if (!gmState?.active) return

        root._savedHyprState = gmState.savedState || {}
        if (AppConfig.gmDisableAnimations) Tokens.durationScale = 0
        root._applyHyprlandGaming()
        root.gamingModeActive = true
    }

    Process {
        id: hyprGetProc
        property var _keys: []
        property int _index: 0

        stdout: StdioCollector {
            id: hyprGetCollector
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    const key = hyprGetProc._keys[hyprGetProc._index]
                    let saved = Object.assign({}, root._savedHyprState)
                    if (parsed.custom !== undefined)
                        saved[key] = parsed.custom
                    else if (parsed.int !== undefined)
                        saved[key] = parsed.int
                    else if (parsed.set !== undefined)
                        saved[key] = parsed.set ? 1 : 0
                    else
                        saved[key] = parsed.str || ""
                    root._savedHyprState = saved
                } catch (e) {
                    console.warn("Gaming mode: failed to parse hyprctl output:", e)
                }

                hyprGetProc._index++
                if (hyprGetProc._index < hyprGetProc._keys.length) {
                    hyprGetProc.command = ["hyprctl", "-j", "getoption", hyprGetProc._keys[hyprGetProc._index]]
                    hyprGetProc.running = true
                } else {
                    root._applyHyprlandGaming()
                }
            }
        }
    }

    Process {
        id: hyprBatchProc
    }

    function toggleGamingMode() {
        if (gamingModeActive)
            disableGamingMode()
        else
            enableGamingMode()
    }

    function enableGamingMode() {
        closeAllPanels()
        _saveAndApplyHyprland()
        if (AppConfig.gmDisableAnimations) Tokens.durationScale = 0
        gamingModeActive = true
        ToastService.info("Gaming mode enabled", 2000)
    }

    function disableGamingMode() {
        _restoreHyprland()
        Tokens.durationScale = 1.0
        gamingModeActive = false
        AppConfig.updateState("gamingMode", { active: false, savedState: {} })
        ToastService.info("Gaming mode disabled", 2000)
    }

    function _saveAndApplyHyprland() {
        const keys = []
        if (AppConfig.gmHyprDisableAnimations) keys.push("animations:enabled")
        if (AppConfig.gmHyprDisableBlur)       keys.push("decoration:blur:enabled")
        if (AppConfig.gmHyprDisableShadows)    keys.push("decoration:shadow:enabled")
        if (AppConfig.gmHyprGaps === 0)        { keys.push("general:gaps_in"); keys.push("general:gaps_out") }
        if (AppConfig.gmHyprRounding === 0)    keys.push("decoration:rounding")

        if (keys.length === 0) {
            gamingModeActive = true
            AppConfig.updateState("gamingMode", { active: true, savedState: {} })
            return
        }

        _savedHyprState = ({})
        hyprGetProc._keys = keys
        hyprGetProc._index = 0
        hyprGetProc.command = ["hyprctl", "-j", "getoption", keys[0]]
        hyprGetProc.running = true
    }

    function _applyHyprlandGaming() {
        const parts = []
        if (AppConfig.gmHyprDisableAnimations) parts.push("keyword animations:enabled false")
        if (AppConfig.gmHyprDisableBlur)       parts.push("keyword decoration:blur:enabled false")
        if (AppConfig.gmHyprDisableShadows)    parts.push("keyword decoration:shadow:enabled false")
        if (AppConfig.gmHyprGaps === 0)        { parts.push("keyword general:gaps_in 0"); parts.push("keyword general:gaps_out 0") }
        if (AppConfig.gmHyprRounding === 0)    parts.push("keyword decoration:rounding 0")

        if (parts.length > 0) {
            hyprBatchProc.command = ["hyprctl", "--batch", parts.join(";")]
            hyprBatchProc.running = true
        }
        AppConfig.updateState("gamingMode", { active: true, savedState: root._savedHyprState })
    }

    function _restoreHyprland() {
        const saved = _savedHyprState
        if (!saved || Object.keys(saved).length === 0)
            return

        const parts = []
        for (const key in saved) {
            parts.push(`keyword ${key} ${saved[key]}`)
        }

        if (parts.length > 0) {
            hyprBatchProc.command = ["hyprctl", "--batch", parts.join(";")]
            hyprBatchProc.running = true
        }

        _savedHyprState = ({})
    }

    GlobalShortcut {
        name: "gamingModeToggle"
        description: "Toggle gaming mode"

        onPressed: {
            root.toggleGamingMode()
        }
    }

    GlobalShortcut {
        name: "brightnessUp"
        description: "Increase screen brightness"
        onPressed: BrightnessService.increase(0.05)
    }

    GlobalShortcut {
        name: "brightnessDown"
        description: "Decrease screen brightness"
        onPressed: BrightnessService.decrease(0.05)
    }

    // IPC Commands для внешнего управления
    IpcHandler {
        target: "globalstates"

        function toggleControlPanel(): void {
            root.controlPanelOpen = !root.controlPanelOpen
        }

        function openControlPanel(): void {
            root.controlPanelOpen = true
        }

        function closeControlPanel(): void {
            root.controlPanelOpen = false
        }

        function toggleDashboard(): void {
            root.dashboardOpen = !root.dashboardOpen
        }

        function toggleLauncher(): void {
            root.launcherOpen = !root.launcherOpen
        }

        function openLauncher(): void {
            root.launcherOpen = true
        }

        function closeLauncher(): void {
            root.launcherOpen = false
        }

        function openControlPanelLeft(): void {
            root.controlPanelLeftOpen = true
        }

        function closeControlPanelLeft(): void {
            root.controlPanelLeftOpen = false
        }

        function closeAll(): void {
            root.closeAllPanels()
        }

        function toggleNotificationCenter(): void {
            root.notificationCenterOpen = !root.notificationCenterOpen
        }

        function openNotificationCenter(): void {
            root.notificationCenterOpen = true
        }

        function closeNotificationCenter(): void {
            root.notificationCenterOpen = false
        }

        function screenshot(): void {
            root.takeScreenshot()
        }

        function screenshotSwappy(): void {
            root.takeScreenshotSwappy()
        }

        function toggleGamingMode(): void {
            root.toggleGamingMode()
        }

        function enableGamingMode(): void {
            root.enableGamingMode()
        }

        function disableGamingMode(): void {
            root.disableGamingMode()
        }

        function togglePowerMenu(): void {
            root.powerMenuOpen = !root.powerMenuOpen
        }

        function openPowerMenu(): void {
            root.powerMenuOpen = true
        }

        function closePowerMenu(): void {
            root.powerMenuOpen = false
        }

        function lockScreen(): void {
            root.lockSession()
        }

        function toggleCheatsheet(): void {
            root.cheatsheetOpen = !root.cheatsheetOpen
        }

        function openCheatsheet(): void {
            root.cheatsheetOpen = true
        }

        function closeCheatsheet(): void {
            root.cheatsheetOpen = false
        }
    }
}
