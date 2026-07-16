import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.core.config

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    // Main panels
    property bool dashboardOpen: false
    property int  dashboardOpenIndex: 0
    property bool notificationCenterOpen: false
    property bool inhibit: false
    property bool launcherOpen: false

    // Lockscreen & Power Menu
    property bool lockscreenActive: false
    property bool powerMenuOpen: false

    // Cheatsheet
    property bool cheatsheetOpen: false

    // Close every mutually-exclusive panel
    function closeAllPanels() {
        dashboardOpen = false
        launcherOpen = false
        notificationCenterOpen = false
        cheatsheetOpen = false
    }

    // Открыть Dashboard на конкретной вкладке
    // tabIndex: 0 = Quick, 1 = Weather, 2 = Calendar, 3 = Audio, 4 = Network
    function openDashboardTab(tabIndex) {
        if (!AppConfig.moduleEnabled("dashboard")) return
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
            case "dashboard-audio":
                openDashboardTab(3)
                return
            case "dashboard-network":
                openDashboardTab(4)
                return
            case "notification-center":
                if (!AppConfig.moduleEnabled("notifications")) return
                notificationCenterOpen = !notificationCenterOpen
                return
            case "launcher":
                if (!AppConfig.moduleEnabled("launcher")) return
                launcherOpen = !launcherOpen
                return
            default:
                console.warn("GlobalStates: unknown clickAction:", action)
        }
    }

    // Lock/Unlock
    function lockSession() {
        // Disabled lockscreen module → lock requests (power menu, loginctl/DBus
        // lock-session) become no-ops. See README caveat; pair with an external locker.
        if (!AppConfig.moduleEnabled("lockscreen")) return
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
                // Match the bare ".Lock" member name (with trailing space
                // before "()"). Plain `Lock` substring also matches `.Unlock`.
                if (data.includes(".Lock ")) root.lockSession()
            }
        }
    }

    // Panels are mutually exclusive: opening one closes the others
    onDashboardOpenChanged: {
        if (dashboardOpen) {
            launcherOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            dashboardOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onNotificationCenterOpenChanged: {
        if (notificationCenterOpen) {
            dashboardOpen = false
            launcherOpen = false
            cheatsheetOpen = false
        }
    }

    onPowerMenuOpenChanged: {
        if (powerMenuOpen) {
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
            cheatsheetOpen = false
        }
    }

    onCheatsheetOpenChanged: {
        if (cheatsheetOpen) {
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
        }
    }

    // Global hotkeys
    GlobalShortcut {
        name: "closeAllPanels"
        description: "Close all open panels"
        onPressed: root.closeAllPanels()
    }

    GlobalShortcut {
        name: "launcherToggle"
        description: "Toggle launcher"
        onPressed: if (AppConfig.moduleEnabled("launcher")) root.launcherOpen = !root.launcherOpen
    }

    GlobalShortcut {
        name: "powerMenuToggle"
        description: "Toggle power menu"
        onPressed: if (AppConfig.moduleEnabled("powerMenu")) root.powerMenuOpen = !root.powerMenuOpen
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle cheatsheet overlay"
        onPressed: if (AppConfig.moduleEnabled("cheatsheet")) root.cheatsheetOpen = !root.cheatsheetOpen
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
        onPressed: if (AppConfig.moduleEnabled("screenshot")) ScreenshotService.takeScreenshot()
    }

    GlobalShortcut {
        name: "screenshotSwappy"
        description: "Take annotated screenshot (swappy)"
        onPressed: if (AppConfig.moduleEnabled("screenshot")) ScreenshotService.takeScreenshotSwappy()
    }

    GlobalShortcut {
        name: "gamingModeToggle"
        description: "Toggle gaming mode"
        onPressed: GamingModeService.toggleGamingMode()
    }

    GlobalShortcut {
        name: "nightLightToggle"
        description: "Toggle night light"
        onPressed: NightLightService.toggle()
    }

    // IPC commands for external control
    IpcHandler {
        target: "globalstates"

        function toggleDashboard(): void {
            if (!AppConfig.moduleEnabled("dashboard")) return
            root.dashboardOpen = !root.dashboardOpen
        }

        function toggleLauncher(): void {
            if (!AppConfig.moduleEnabled("launcher")) return
            root.launcherOpen = !root.launcherOpen
        }

        function openLauncher(): void {
            if (!AppConfig.moduleEnabled("launcher")) return
            root.launcherOpen = true
        }

        function closeLauncher(): void {
            root.launcherOpen = false
        }

        function closeAll(): void {
            root.closeAllPanels()
        }

        function toggleNotificationCenter(): void {
            if (!AppConfig.moduleEnabled("notifications")) return
            root.notificationCenterOpen = !root.notificationCenterOpen
        }

        function openNotificationCenter(): void {
            if (!AppConfig.moduleEnabled("notifications")) return
            root.notificationCenterOpen = true
        }

        function closeNotificationCenter(): void {
            root.notificationCenterOpen = false
        }

        function screenshot(): void {
            if (!AppConfig.moduleEnabled("screenshot")) return
            ScreenshotService.takeScreenshot()
        }

        function screenshotSwappy(): void {
            if (!AppConfig.moduleEnabled("screenshot")) return
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
            if (!AppConfig.moduleEnabled("powerMenu")) return
            root.powerMenuOpen = !root.powerMenuOpen
        }

        function openPowerMenu(): void {
            if (!AppConfig.moduleEnabled("powerMenu")) return
            root.powerMenuOpen = true
        }

        function closePowerMenu(): void {
            root.powerMenuOpen = false
        }

        function lockScreen(): void {
            root.lockSession()
        }

        function toggleCheatsheet(): void {
            if (!AppConfig.moduleEnabled("cheatsheet")) return
            root.cheatsheetOpen = !root.cheatsheetOpen
        }

        function openCheatsheet(): void {
            if (!AppConfig.moduleEnabled("cheatsheet")) return
            root.cheatsheetOpen = true
        }

        function closeCheatsheet(): void {
            root.cheatsheetOpen = false
        }

        function toggleNightLight(): void {
            NightLightService.toggle()
        }

        function setNightLightTemperature(temp: int): void {
            NightLightService.setTemperature(temp)
        }
    }
}
