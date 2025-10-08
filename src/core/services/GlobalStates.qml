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
    property bool mediaControlsOpen: false
    property bool showDateSelector: false
    property bool darkMode: true
    property bool inhibit: false

    // OSD элементы (для будущего расширения)
    property bool osdVolumeOpen: false
    property bool osdBrightnessOpen: false

    // Утилиты для закрытия всех панелей
    function closeAllPanels() {
        controlPanelOpen = false
        dashboardOpen = false
        mediaControlsOpen = false
    }

    function closeAllOSD() {
        osdVolumeOpen = false
        osdBrightnessOpen = false
    }

    // Автозакрытие панелей при открытии другой
    onControlPanelOpenChanged: {
        if (controlPanelOpen) {
            dashboardOpen = false
            mediaControlsOpen = false
        }
    }

    onDashboardOpenChanged: {
        if (dashboardOpen) {
            controlPanelOpen = false
            mediaControlsOpen = false
        }
    }

    onMediaControlsOpenChanged: {
        if (mediaControlsOpen) {
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
        name: "mediaControlsToggle"
        description: "Toggle media controls"

        onPressed: {
            root.mediaControlsOpen = !root.mediaControlsOpen
        }
    }

    GlobalShortcut {
        name: "closeAllPanels"
        description: "Close all open panels"

        onPressed: {
            root.closeAllPanels()
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

        function openControlPanelLeft(): void {
            root.controlPanelLeftOpen = true
        }

        function closeControlPanelLeft(): void {
            root.controlPanelLeftOpen = false
        }

        function toggleMediaControls(): void {
            root.mediaControlsOpen = !root.mediaControlsOpen
        }

        function openMediaControls(): void {
            root.mediaControlsOpen = true
        }

        function closeMediaControls(): void {
            root.mediaControlsOpen = false
        }

        function closeAll(): void {
            root.closeAllPanels()
        }
    }
}
