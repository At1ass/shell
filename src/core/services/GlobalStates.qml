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
    property bool showDateSelector: false
    property bool darkMode: true
    property bool inhibit: false
    property bool launcherOpen: false

    // OSD элементы (для будущего расширения)
    property bool osdVolumeOpen: false
    property bool osdBrightnessOpen: false

    // Утилиты для закрытия всех панелей
    function closeAllPanels() {
        controlPanelOpen = false
        dashboardOpen = false
        launcherOpen = false
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
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            controlPanelOpen = false
            launcherOpen = false
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            controlPanelOpen = false
            dashboardOpen = false
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
    }
}
