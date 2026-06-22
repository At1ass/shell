pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.src.core.config

// Dock entry point. A Wayland layer surface does not reliably reconfigure its anchors and
// size on the fly, so changing `dock.position` at runtime is handled by destroying and
// recreating the DockPanel (matches a fresh start) instead of mutating the live surface.
// All dock logic lives in DockPanel.
Scope {
    id: root
    required property ShellScreen screen

    property var _panel: null

    Component {
        id: panelComponent
        DockPanel { screen: root.screen }
    }

    function _rebuild() {
        if (_panel) {
            _panel.destroy()
            _panel = null
        }
        _panel = panelComponent.createObject(root)
    }

    Component.onCompleted: _rebuild()

    // Rebuild only when the position actually changes (not on every config reload).
    Connections {
        target: AppConfig
        function onDockPositionChanged() { root._rebuild() }
    }
}
