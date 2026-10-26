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

    readonly property bool connectionsOpen: activePanel === "connections"
    property string connectionsSection: ""
    property Item connectionsSource: null
    property int dashboardOpenIndex: 0

    function openConnections(section, source) {
        if (root.lockscreenActive || !AppConfig.moduleEnabled("connections")) return
        root.connectionsSection = ["wifi", "bluetooth", "vpn", "ethernet"].includes(section) ? section : ""
        root.connectionsSource = source ?? null
        root.openPanel("connections", root.screenForItem(source))
    }

    function toggleConnections(section, source) {
        if (root.connectionsOpen && (!section || root.connectionsSection === section)) root.closePanel("connections")
        else root.openConnections(section, source)
    }

    readonly property bool audioOpen: activePanel === "audio"
    property Item audioSource: null
    function openAudio(source) {
        if (root.lockscreenActive || !AppConfig.moduleEnabled("audio")) return
        root.audioSource = source ?? null
        root.openPanel("audio", root.screenForItem(source))
    }
    function toggleAudio(source) {
        if (root.audioOpen) root.closePanel("audio")
        else root.openAudio(source)
    }
    onAudioOpenChanged: if (!audioOpen) root.audioSource = null

    function screenForItem(source) {
        let targetScreen = null
        if (source) {
            const win = source.Window.window
            const pos = source.mapToItem(null, 0, 0)
            const x = pos.x + (win?.x ?? 0)
            const y = pos.y + (win?.y ?? 0)
            for (const screen of Quickshell.screens) {
                if (!screen) continue
                if (x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height) {
                    targetScreen = screen
                    break
                }
            }
        }
        return targetScreen
    }

    onConnectionsOpenChanged: if (!connectionsOpen) root.connectionsSource = null

    // Lockscreen has its own lifecycle (WlSessionLock), not a panel.
    property bool lockscreenActive: false
    property string lockscreenScreenName: ""

    // Panel name → modules.* key gating it.
    readonly property var _panelModule: ({
        "audio": "audio",
        "connections": "connections",
        "dashboard": "dashboard",
        "launcher": "launcher",
        "notificationCenter": "notifications",
        "cheatsheet": "cheatsheet",
        "powermenu": "powerMenu"
    })

    // Panels whose tree is retained after their first open, so the next open
    // costs nothing to construct. A plain list, reassigned rather than mutated,
    // because bindings have to see it change — `panelRetained` is read from the
    // `active` binding of every panel loader.
    property var retainedPanels: []

    function panelRetained(name) {
        return root.retainedPanels.indexOf(name) !== -1
    }

    // The output a retained panel must map onto. Resolved when the panel opens
    // and BEFORE `activePanel` flips, so the window is still invisible when its
    // screen changes and there is no visible remap. Panels used to resolve this
    // once in Component.onCompleted, which was correct only while every open
    // rebuilt the window.
    property ShellScreen activePanelScreen: null

    // Emitted after a panel becomes the active one. A retained panel keeps
    // whatever the user last left in it — a search query, a scroll position,
    // keyboard focus — so each panel resets its own transient state here.
    signal panelOpened(string name)

    function openPanel(name, preferredScreen) {
        const mod = _panelModule[name]
        if (!mod) { console.warn("GlobalStates: unknown panel:", name); return }
        if (root.lockscreenActive || !AppConfig.moduleEnabled(mod)) return

        PopoutsState.closePopout()
        const s = preferredScreen ?? root.focusedScreen()
        if (s) root.activePanelScreen = s

        if (AppConfig.panelKeptLoaded(name) && !root.panelRetained(name))
            root.retainedPanels = root.retainedPanels.concat([name])

        activePanel = name
        root.panelOpened(name)
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
    // Resolved by openPanel into `activePanelScreen`, once per open and before
    // the open flag flips — so a panel does not chase the focused monitor while
    // it is already on screen, and a retained panel still lands on the right
    // output. Panels read `activePanelScreen`; they must not call this from
    // Component.onCompleted, which only re-resolved because every open used to
    // rebuild the window.
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor
        if (focused) {
            for (const screen of Quickshell.screens) {
                if (screen && screen.name === focused.name) return screen
            }
        }
        return Quickshell.screens.find(screen => screen !== null) ?? null
    }

    // Open the dashboard on a specific tab.
    // tabIndex: 0 = Quick, 1 = Weather, 2 = Calendar, legacy 3 opens Audio, legacy 4 opens Connections
    function openDashboardTab(tabIndex) {
        // Clamp: an out-of-range index (IPC typo) would deactivate every
        // tab Loader and open a blank dashboard.
        if (tabIndex === 3) { root.openAudio(null); return }
        if (tabIndex === 4) { root.openConnections("wifi", null); return }
        dashboardOpenIndex = Math.max(0, Math.min(2, tabIndex))
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
            case "audio":
            case "dashboard-audio":    toggleAudio(null); return
            case "connections":         toggleConnections("", null); return
            case "connections-wifi":    toggleConnections("wifi", null); return
            case "connections-bluetooth": toggleConnections("bluetooth", null); return
            case "dashboard-network":  toggleConnections("wifi", null); return
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
        lockscreenScreenName = focusedScreen()?.name ?? ""
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

    Connections {
        target: SessionMonitor
        function onLockRequested() { root.lockSession() }
        function onUnlockRequested() { root.unlockSession() }
    }

    GlobalShortcut {
        name: "connectionsToggle"
        description: "Toggle connections panel"
        onPressed: root.toggleConnections("", null)
    }

    GlobalShortcut {
        name: "audioToggle"
        description: "Toggle audio panel"
        onPressed: root.toggleAudio(null)
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

        function toggleAudio(): void { root.toggleAudio(null) }
        function openAudio(): void { root.openAudio(null) }
        function closeAudio(): void { root.closePanel("audio") }

        function toggleConnections(): void { root.toggleConnections("", null) }
        function openConnections(section: string): void { root.openConnections(section, null) }
        function closeConnections(): void { root.closePanel("connections") }

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

        function nightLight(): bool {
            return NightLightService.enabled
        }

        function toggleIdleInhibitor(): bool {
            IdleInhibitorService.toggleInhibit()
            return IdleInhibitorService.inhibit
        }

        function setIdleInhibitor(enabled: bool): void {
            IdleInhibitorService.setInhibit(enabled)
        }

        function setIdleInhibitorFor(minutes: int): bool { return IdleInhibitorService.setForMinutes(minutes) }
        function idleInhibitorUntil(): string { return IdleInhibitorService.temporary ? new Date(IdleInhibitorService.expiresAt).toISOString() : "" }
        function idleInhibitor(): bool {
            return IdleInhibitorService.inhibit
        }
    }
}
