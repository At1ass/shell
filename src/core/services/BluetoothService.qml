pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    // Bluetooth adapter
    readonly property var adapter: Bluetooth.defaultAdapter

    // State
    property bool enabled: adapter ? adapter.enabled : false
    property bool connected: false
    property int connectedDeviceCount: 0

    // Material icon based on state
    readonly property string icon: {
        if (!enabled) return "bluetooth_disabled"
        if (connected) return "bluetooth_connected"
        return "bluetooth"
    }

    // Toggle Bluetooth
    function toggle() {
        if (adapter) {
            adapter.enabled = !adapter.enabled
        }
    }

    // Open system bluetooth settings
    function openSettings() {
        Quickshell.execDetached(["blueman-manager"])
    }

    // Monitor adapter state
    Connections {
        target: adapter

        function onEnabledChanged() {
            root.enabled = adapter.enabled
        }
    }

    // Monitor connected devices (only when Bluetooth is enabled)
    Timer {
        interval: 2000
        running: root.enabled
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            let count = 0
            const devices = adapter?.devices || []

            for (let i = 0; i < devices.length; i++) {
                if (devices[i] && devices[i].connected) {
                    count++
                }
            }

            root.connected = count > 0
            root.connectedDeviceCount = count
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            root.connected = false
            root.connectedDeviceCount = 0
        }
    }

    Component.onCompleted: {
        if (adapter) {
            enabled = adapter.enabled
        }
    }
}
