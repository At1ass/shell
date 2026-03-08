pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.src.core.services

Singleton {
    id: root

    // Bluetooth adapter
    readonly property var adapter: Bluetooth.defaultAdapter

    // Background bluetoothctl agent for pairing confirmation.
    // KeyboardDisplay capability handles PIN confirmation dialogs (phones etc).
    // Continuously sends "yes" to auto-confirm any passkey prompts.
    Process {
        id: btAgent
        running: true
        command: ["sh", "-c", "{ echo 'agent KeyboardDisplay'; echo 'default-agent'; while true; do sleep 0.5; echo 'yes'; done; } | bluetoothctl"]
    }

    // State
    property bool enabled: adapter ? adapter.enabled : false
    property bool connected: false
    property int connectedDeviceCount: 0

    // All adapter devices (UntypedObjectModel)
    readonly property var devices: adapter ? adapter.devices : []

    // Filtered device lists for UI
    property var pairedDevices: []
    property var discoveredDevices: []
    property bool scanning: false

    // Device pending auto-connect after pairing
    property var _pendingConnectDevice: null

    // Address of device currently being connected/disconnected/paired
    property string busyDeviceAddress: ""

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

    // Start scanning for new devices
    function startScan() {
        if (adapter && enabled) {
            adapter.discovering = true
            scanning = true
        }
    }

    // Stop scanning
    function stopScan() {
        if (adapter) {
            adapter.discovering = false
            scanning = false
        }
    }

    // Connect a paired/bonded device (direct property assignment like caelesia)
    function connectDevice(device) {
        busyDeviceAddress = device.address || ""
        device.trusted = true
        device.connected = true
    }

    // Disconnect from a device
    function disconnectDevice(device) {
        busyDeviceAddress = device.address || ""
        device.connected = false
    }

    // Pair a new device — user confirms on the remote device,
    // then auto-connect fires via _pendingConnectDevice watcher
    function pairDevice(device) {
        busyDeviceAddress = device.address || ""
        root._pendingConnectDevice = device
        device.pair()
    }

    // Forget a device
    function forgetDevice(device) {
        device.forget()
    }

    // Open system bluetooth settings
    function openSettings() {
        Quickshell.execDetached(["blueman-manager"])
    }

    // Auto-connect after pairing completes
    Timer {
        id: pairWatchTimer
        interval: 1000
        repeat: true
        running: root._pendingConnectDevice !== null

        onTriggered: {
            const dev = root._pendingConnectDevice
            if (!dev) { stop(); return }

            if (dev.paired) {
                dev.trusted = true
                dev.connected = true
                root._pendingConnectDevice = null
                root.busyDeviceAddress = ""
            }
        }
    }

    // Timeout — give up waiting for pairing after 30s
    Timer {
        id: pairTimeoutTimer
        interval: 30000
        running: root._pendingConnectDevice !== null

        onTriggered: {
            if (root._pendingConnectDevice) {
                console.warn("BluetoothService: pairing timed out for", root._pendingConnectDevice.address)
                ToastService.warning("Pairing timed out")
                root._pendingConnectDevice = null
                root.busyDeviceAddress = ""
            }
        }
    }

    // Get device type icon
    function deviceIcon(device) {
        if (!device) return "bluetooth"
        const icon = device.icon || ""
        if (icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1)
            return "headphones"
        if (icon.indexOf("input") !== -1 || icon.indexOf("mouse") !== -1)
            return "mouse"
        if (icon.indexOf("keyboard") !== -1)
            return "keyboard"
        if (icon.indexOf("phone") !== -1)
            return "smartphone"
        if (icon.indexOf("computer") !== -1)
            return "computer"
        return "bluetooth"
    }

    // Monitor adapter state
    Connections {
        target: adapter

        function onEnabledChanged() {
            root.enabled = adapter.enabled
        }
    }

    // Update device lists and connection count
    Timer {
        interval: 2000
        running: root.enabled
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            let count = 0
            const paired = []
            const discovered = []

            if (!adapter || !adapter.devices) {
                root.connected = false
                root.connectedDeviceCount = 0
                root.pairedDevices = []
                root.discoveredDevices = []
                return
            }

            const devs = adapter.devices.values

            for (const d of devs) {
                if (!d) continue

                if (d.connected) count++

                if (d.paired || d.trusted) {
                    paired.push({
                        name: d.name || "",
                        address: d.address || "",
                        connected: d.connected || false,
                        battery: d.batteryAvailable ? d.battery : -1,
                        icon: d.icon || "",
                        iconName: root.deviceIcon(d),
                        device: d
                    })
                } else if (!d.blocked) {
                    // Filter out unnamed / MAC-only devices
                    const name = (d.name || "").trim()
                    if (name.length === 0 || name === d.address) continue

                    discovered.push({
                        name: name,
                        address: d.address || "",
                        connected: false,
                        battery: -1,
                        icon: d.icon || "",
                        iconName: root.deviceIcon(d),
                        device: d
                    })
                }
            }

            root.connected = count > 0
            root.connectedDeviceCount = count
            root.pairedDevices = paired
            root.discoveredDevices = discovered

            // Clear busy state once the device list reflects the change
            if (root.busyDeviceAddress && !root._pendingConnectDevice)
                root.busyDeviceAddress = ""
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            root.connected = false
            root.connectedDeviceCount = 0
            root.pairedDevices = []
            root.discoveredDevices = []
            root.scanning = false
        }
    }

    Component.onCompleted: {
        if (adapter) {
            enabled = adapter.enabled
        }
    }
}
