import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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

    // OSD элементы (для будущего расширения)
    property bool osdVolumeOpen: false
    property bool osdBrightnessOpen: false

    // Утилиты для закрытия всех панелей
    function closeAllPanels() {
        controlPanelOpen = false
        dashboardOpen = false
        launcherOpen = false
        notificationCenterOpen = false
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


    // Автозакрытие панелей при открытии другой
    onControlPanelOpenChanged: {
        if (controlPanelOpen) {
            dashboardOpen = false
            launcherOpen = false
            notificationCenterOpen = false
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            controlPanelOpen = false
            launcherOpen = false
            notificationCenterOpen = false
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            notificationCenterOpen = false
        }
    }

    onNotificationCenterOpenChanged: {
        if (notificationCenterOpen) {
            controlPanelOpen = false
            dashboardOpen = false
            launcherOpen = false
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
    }
}
