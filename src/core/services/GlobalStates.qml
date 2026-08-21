import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.core.config

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    // ── Panel state machine ─────────────────────────────────────────
    // Exactly one mutually-exclusive panel may be open; "" = none.
    // The open/closed booleans below are DERIVED, so the exclusivity
    // invariant is structural — there is nothing to keep in sync.
    property string activePanel: ""

    readonly property bool dashboardOpen: activePanel === "dashboard"
    readonly property bool launcherOpen: activePanel === "launcher"
    readonly property bool notificationCenterOpen: activePanel === "notificationCenter"
    readonly property bool cheatsheetOpen: activePanel === "cheatsheet"
    readonly property bool powerMenuOpen: activePanel === "powermenu"

    property int  dashboardOpenIndex: 0
    property bool inhibit: false

    // Lockscreen has its own lifecycle (WlSessionLock), not a panel.
    property bool lockscreenActive: false

    // Panel name → modules.* key gating it.
    readonly property var _panelModule: ({
        "dashboard": "dashboard",
        "launcher": "launcher",
        "notificationCenter": "notifications",
        "cheatsheet": "cheatsheet",
        "powermenu": "powerMenu"
    })

    function openPanel(name) {
        const mod = _panelModule[name]
        if (!mod) { console.warn("GlobalStates: unknown panel:", name); return }
        if (!AppConfig.moduleEnabled(mod)) return
        activePanel = name
    }

    function closePanel(name) {
        if (activePanel === name) activePanel = ""
    }

    function togglePanel(name) {
        if (activePanel === name) activePanel = ""
        else openPanel(name)
    }

    function closeAllPanels() {
        activePanel = ""
    }

    // The output the user is currently working on.
    //
    // Overlay panels are SINGLE windows, not per-screen `Variants`, so they must
    // pick an output explicitly — a PanelWindow with no `screen` is mapped to
    // whichever output the compositor defaults to, which meant pressing the
    // launcher hotkey on monitor 2 opened it on monitor 1.
    //
    // Callers resolve this ONCE, in Component.onCompleted: every panel lives
    // inside a LazyLoader keyed on its own open state, so each open constructs a
    // fresh window and re-resolves — and the panel does not chase the focused
    // monitor while it is already on screen. Assigning before the window exists
    // is the cheap path (Quickshell applies it in completeWindow, no remap).
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor
        if (focused) {
            for (const screen of Quickshell.screens) {
                if (screen.name === focused.name) return screen
            }
        }
        return Quickshell.screens[0] ?? null
    }

    // Open the dashboard on a specific tab.
    // tabIndex: 0 = Quick, 1 = Weather, 2 = Calendar, 3 = Audio, 4 = Network
    function openDashboardTab(tabIndex) {
        // Clamp: an out-of-range index (IPC typo) would deactivate every
        // tab Loader and open a blank dashboard.
        dashboardOpenIndex = Math.max(0, Math.min(4, tabIndex))
        openPanel("dashboard")
    }

    // Handle widget click actions from bar configuration
    function handleClickAction(action) {
        if (!action)
            return

        switch (action) {
            case "dashboard-quick":    openDashboardTab(0); return
            case "dashboard-weather":  openDashboardTab(1); return
            case "dashboard-calendar": openDashboardTab(2); return
            case "dashboard-audio":    openDashboardTab(3); return
            case "dashboard-network":  openDashboardTab(4); return
            case "notification-center": togglePanel("notificationCenter"); return
            case "launcher":            togglePanel("launcher"); return
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
        closePanel("powermenu")
        switch (action) {
            case "lock":     lockSession(); return
            case "suspend":  powerProc.command = ["systemctl", "suspend"]; break
            case "reboot":   powerProc.command = ["systemctl", "reboot"]; break
            case "shutdown": powerProc.command = ["systemctl", "poweroff"]; break
            // Hyprland 0.56 dropped the string dispatch form; see HyprlandDispatch.
            case "logout":   HyprlandDispatch.exitCompositor(); return
            default: return
        }
        if (!powerProc.running) powerProc.running = true
        else ToastService.warning("Power action already in progress")
    }

    // DBus lock signal listener (loginctl lock-session).
    // logind emits Lock/Unlock on the CONCRETE session object path
    // (/org/freedesktop/login1/session/_3xx), not on the /session/auto
    // alias, so monitor the whole destination and match the member name.
    Process {
        id: lockListenerProc
        command: ["gdbus", "monitor", "--system",
                  "--dest", "org.freedesktop.login1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                // Member arrives as "...session.Lock ()"; the trailing space
                // keeps the bare `Lock` from also matching `.Unlock`.
                if (data.includes(".Session.Lock ") || data.includes(".Lock ()"))
                    root.lockSession()
                else if (data.includes(".Session.Unlock ") || data.includes(".Unlock ()"))
                    root.unlockSession()
            }
        }
        // dbus-daemon restart or gdbus death would silently kill lock
        // handling; restart the monitor after a short delay.
        onExited: lockListenerRestart.start()
    }
    Timer {
        id: lockListenerRestart
        interval: 2000
        onTriggered: if (!lockListenerProc.running) lockListenerProc.running = true
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
        onPressed: root.togglePanel("launcher")
    }

    GlobalShortcut {
        name: "powerMenuToggle"
        description: "Toggle power menu"
        onPressed: root.togglePanel("powermenu")
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle cheatsheet overlay"
        onPressed: root.togglePanel("cheatsheet")
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
            root.togglePanel("dashboard")
        }

        function openDashboardTab(tabIndex: int): void {
            root.openDashboardTab(tabIndex)
        }

        function toggleLauncher(): void {
            root.togglePanel("launcher")
        }

        function openLauncher(): void {
            root.openPanel("launcher")
        }

        function closeLauncher(): void {
            root.closePanel("launcher")
        }

        function closeAll(): void {
            root.closeAllPanels()
        }

        function toggleNotificationCenter(): void {
            root.togglePanel("notificationCenter")
        }

        function openNotificationCenter(): void {
            root.openPanel("notificationCenter")
        }

        function closeNotificationCenter(): void {
            root.closePanel("notificationCenter")
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
            root.togglePanel("powermenu")
        }

        function openPowerMenu(): void {
            root.openPanel("powermenu")
        }

        function closePowerMenu(): void {
            root.closePanel("powermenu")
        }

        function lockScreen(): void {
            root.lockSession()
        }

        // Query, not a command. A failed config load takes the WlSessionLock
        // client down with it and leaves the session locked with no way in, so
        // anything editing this config unattended must be able to ask first.
        // loginctl's LockedHint cannot answer: hypridle calls lockScreen()
        // over IPC directly, never through `loginctl lock-session`, so the
        // hint stays "no" while the session is in fact locked.
        function locked(): bool {
            return root.lockscreenActive
        }

        function toggleCheatsheet(): void {
            root.togglePanel("cheatsheet")
        }

        function openCheatsheet(): void {
            root.openPanel("cheatsheet")
        }

        function closeCheatsheet(): void {
            root.closePanel("cheatsheet")
        }

        function toggleNightLight(): void {
            NightLightService.toggle()
        }

        function setNightLightTemperature(temp: int): void {
            NightLightService.setTemperature(temp)
        }
    }
}
