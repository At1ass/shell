pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.src.core.services

// Bluetooth via Quickshell's native BlueZ model, fully event-driven:
// device lists rebuild only when a device appears/disappears or one of its
// relevant properties changes (no polling).
//
// SECURITY: no background pairing agent. The old always-on bluetoothctl
// agent auto-answered "yes" to EVERY passkey/confirmation prompt — including
// pairing attempts the user never initiated. Pairing now relies on
// device.pair() (works for simple devices) or an interactive agent
// (blueman) for confirmation-requiring peers.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    // Pure bindings — the native model notifies; no manual sync handlers.
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    property bool connected: false
    property int connectedDeviceCount: 0

    // Filtered device lists for UI (rebuilt by _recompute on real changes).
    property var pairedDevices: []
    property var discoveredDevices: []

    // Device pending auto-connect after pairing.
    property var _pendingConnectDevice: null

    // Address of device currently being connected/disconnected/paired.
    property string busyDeviceAddress: ""

    readonly property string icon: {
        if (!enabled) return "bluetooth_disabled"
        if (connected) return "bluetooth_connected"
        return "bluetooth"
    }

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled
    }

    function startScan() {
        if (adapter && enabled) adapter.discovering = true
    }

    function stopScan() {
        if (adapter) adapter.discovering = false
    }

    // Connect a paired/bonded device (direct property assignment).
    function connectDevice(device) {
        busyDeviceAddress = device.address || ""
        device.trusted = true
        device.connected = true
    }

    function disconnectDevice(device) {
        busyDeviceAddress = device.address || ""
        device.connected = false
    }

    // Pair a new device — completion is observed via the device's
    // pairedChanged (watched below), then auto-connect fires.
    function pairDevice(device) {
        busyDeviceAddress = device.address || ""
        root._pendingConnectDevice = device
        device.pair()
    }

    function forgetDevice(device) {
        device.forget()
    }

    function openSettings() {
        Quickshell.execDetached(["blueman-manager"])
    }

    // Give up waiting for pairing after 30s.
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

    // ── Event-driven device list ─────────────────────────────────────
    // One Connections watcher per device; any relevant change coalesces
    // into a single _recompute via Qt.callLater.

    function _scheduleRecompute() {
        Qt.callLater(root._recompute)
    }

    Instantiator {
        model: root.adapter?.devices ?? null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root._scheduleRecompute() }
            function onPairedChanged()    { root._scheduleRecompute() }
            function onTrustedChanged()   { root._scheduleRecompute() }
            function onBlockedChanged()   { root._scheduleRecompute() }
            function onNameChanged()      { root._scheduleRecompute() }
            function onBatteryChanged()   { root._scheduleRecompute() }
        }
        onObjectAdded: root._scheduleRecompute()
        onObjectRemoved: root._scheduleRecompute()
    }

    onEnabledChanged: _scheduleRecompute()
    Component.onCompleted: _scheduleRecompute()

    function _recompute() {
        if (!adapter || !adapter.devices || !enabled) {
            connected = false
            connectedDeviceCount = 0
            pairedDevices = []
            discoveredDevices = []
            return
        }

        let count = 0
        const paired = []
        const discovered = []

        for (const d of adapter.devices.values) {
            if (!d) continue

            if (d.connected) count++

            if (d.paired || d.trusted) {
                paired.push({
                    name: d.name || "",
                    address: d.address || "",
                    connected: d.connected || false,
                    battery: d.batteryAvailable ? d.battery : -1,
                    icon: d.icon || "",
                    iconName: deviceIcon(d),
                    device: d
                })
            } else if (!d.blocked) {
                // Filter out unnamed / MAC-only devices.
                const name = (d.name || "").trim()
                if (name.length === 0 || name === d.address) continue

                discovered.push({
                    name: name,
                    address: d.address || "",
                    connected: false,
                    battery: -1,
                    icon: d.icon || "",
                    iconName: deviceIcon(d),
                    device: d
                })
            }
        }

        connected = count > 0
        connectedDeviceCount = count
        pairedDevices = paired
        discoveredDevices = discovered

        // Auto-connect once pairing completed (was a 1 s polling timer).
        const pending = _pendingConnectDevice
        if (pending && pending.paired) {
            pending.trusted = true
            pending.connected = true
            _pendingConnectDevice = null
            busyDeviceAddress = ""
        }

        // Clear busy state once the device list reflects the change.
        if (busyDeviceAddress && !_pendingConnectDevice)
            busyDeviceAddress = ""
    }
}
