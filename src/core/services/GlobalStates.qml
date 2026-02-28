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
    // tabIndex: 0 = Quick, 1 = Weather, 2 = Calendar, 3 = System
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
    Process {
        id: powerProc
        onExited: (exitCode) => {
            if (exitCode !== 0)
                ToastService.error("Power action failed (exit " + exitCode + ")")
        }
    }

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
        onPressed: root.controlPanelOpen = !root.controlPanelOpen
    }

    GlobalShortcut {
        name: "closeAllPanels"
        description: "Close all open panels"
        onPressed: root.closeAllPanels()
    }

    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggle launcher"
        onPressed: root.launcherOpen = !root.launcherOpen
    }

    GlobalShortcut {
        name: "powerMenuToggle"
        description: "Toggle power menu"
        onPressed: root.powerMenuOpen = !root.powerMenuOpen
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle cheatsheet overlay"
        onPressed: root.cheatsheetOpen = !root.cheatsheetOpen
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

    GlobalShortcut {
        name: "screenshot"
        description: "Take a screenshot (area)"
        onPressed: ScreenshotService.takeScreenshot()
    }

    GlobalShortcut {
        name: "screenshotSwappy"
        description: "Take annotated screenshot (swappy)"
        onPressed: ScreenshotService.takeScreenshotSwappy()
    }

    GlobalShortcut {
        name: "gamingModeToggle"
        description: "Toggle gaming mode"
        onPressed: GamingModeService.toggleGamingMode()
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
            ScreenshotService.takeScreenshot()
        }

        function screenshotSwappy(): void {
            ScreenshotService.takeScreenshotSwappy()
        }

        function toggleGamingMode(): void {
            GamingModeService.toggleGamingMode()
        }

        function enableGamingMode(): void {
            GamingModeService.enableGamingMode()
        }

        function disableGamingMode(): void {
            GamingModeService.disableGamingMode()
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
