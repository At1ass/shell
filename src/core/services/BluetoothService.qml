pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.src.core.config
import qs.src.core.services

// Bluetooth via Quickshell's native BlueZ model, fully event-driven:
// device lists rebuild only when a device appears/disappears or one of its
// relevant properties changes (no polling).
//
// Native agent callbacks are isolated in an optional loader so installing a new
// plugin version cannot make the complete shell configuration unloadable.
Singleton {
    id: root

    // Retained panels stay alive when hidden; discovery must stop on close.
    Connections {
        target: GlobalStates
        function onConnectionsOpenChanged() {
            if (!GlobalStates.connectionsOpen) { root.stopScan(); root.cancelPairing() }
        }
        function onLockscreenActiveChanged() { if (GlobalStates.lockscreenActive) root.cancelPairing() }
        function onConnectionsSectionChanged() { if (GlobalStates.connectionsSection !== "bluetooth") root.cancelPairing() }
    }

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // ObjectModel values are reactive but absent from the generated Qt typeinfo.
    readonly property QtObject _deviceModel: adapter?.devices ?? null
    readonly property list<BluetoothDevice> _devices: _deviceModel ? (_deviceModel["values"] ?? []) : []

    // Pure bindings — the native model notifies; no manual sync handlers.
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    property bool connected: false
    property int connectedDeviceCount: 0

    // Filtered device lists for UI (rebuilt by _recompute on real changes).
    property var pairedDevices: []
    property var discoveredDevices: []

    property string errorMessage: ""
    Loader {
        id: agentLoader
        active: AppConfig.moduleEnabled("connections") && AppConfig.bluetoothAgentEnabled
        source: "connectivity/NativeBluetoothAgent.qml"
    }
    readonly property QtObject pairingAgent: agentLoader.item
    onPairingAgentChanged: {
        if (!pairingAgent && root._nativePair) root._finishPair(root._pairingPath, false, "Pairing cancelled")
    }
    function agentValue(name, fallback) { return pairingAgent ? (pairingAgent[name] ?? fallback) : fallback }
    function agentCall(name, args) {
        const agent = pairingAgent
        return agent && typeof agent[name] === "function" ? agent[name](...args) : false
    }
    readonly property bool agentRegistered: agentValue("registered", false)
    readonly property bool agentBusy: agentValue("busy", false)
    readonly property string pairingToken: agentValue("requestToken", "")
    readonly property string pairingKind: agentValue("requestKind", "")
    readonly property string pairingName: agentValue("deviceName", "")
    readonly property string pairingAddress: agentValue("deviceAddress", "")
    readonly property string pairingCode: agentValue("code", "")
    readonly property string pairingUuid: agentValue("serviceUuid", "")
    readonly property int pairingEntered: agentValue("entered", 0)
    readonly property string pairingError: agentValue("validationError", "")
    readonly property bool pairingPending: root._pendingConnectDevice !== null
    property BluetoothDevice _pendingConnectDevice: null
    property string _pairingPath: ""
    property bool _nativePair: false
    property bool _fallbackPairStarted: false

    function answerPairing(token, value) { return agentCall("submit", [token, value]) }
    function rejectPairing(token) { return agentCall("reject", [token]) }
    function cancelPairing() {
        if (!root.pairingPending) return
        if (root._nativePair) { root.agentCall("abort", []); return }
        const device = root._pendingConnectDevice
        root._pairingPath = ""
        root._pendingConnectDevice = null
        if (device?.pairing) device.cancelPair()
        root.busyDeviceAddress = ""
    }
    function _finishPair(path, success, message) {
        const device = root._pendingConnectDevice
        if (!path || root._pairingPath !== path) return
        root._pairingPath = ""
        root._nativePair = false
        root._pendingConnectDevice = null
        if (success && device && root.enabled) {
            device.trusted = true
            device.connected = true
        } else {
            root.busyDeviceAddress = ""
            root.errorMessage = message || "Pairing failed. Check the device and try again."
        }
        root._scheduleRecompute()
    }
    Connections {
        target: agentLoader.item
        ignoreUnknownSignals: true
        function onOperationFinished(path: string, success: bool, error: string) { root._finishPair(path, success, error) }
        function onOperationCancelled(path: string, reason: string) {
            root._finishPair(path, false, reason)
        }
    }
    onAgentBusyChanged: {
        if (!root.agentBusy && !root.pairingPending) root._scheduleRecompute()
    }
    Connections {
        target: SessionMonitor
        function onResumed() { root.cancelPairing() }
    }

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

    // Target connected-state of the in-flight operation; busy clears only
    // when the busy device actually reaches it (any unrelated recompute —
    // battery ticks, other devices — used to wipe the busy flag instantly).
    property bool _busyTargetConnected: false

    // Connect a paired/bonded device (direct property assignment).
    function connectDevice(device) {
        if (!device || busyDeviceAddress !== "" || root.agentBusy) return
        root.errorMessage = ""
        busyDeviceAddress = device.address || ""
        _busyTargetConnected = true
        device.trusted = true
        device.connected = true
    }

    function disconnectDevice(device) {
        if (!device || busyDeviceAddress !== "" || root.agentBusy) return
        root.errorMessage = ""
        busyDeviceAddress = device.address || ""
        _busyTargetConnected = false
        device.connected = false
    }

    // Only user-initiated operations arm the application-scoped agent.
    function pairDevice(device) {
        if (!device || device.paired || busyDeviceAddress !== "" || root.agentBusy) return
        root.errorMessage = ""
        root._nativePair = false
        root._fallbackPairStarted = false
        if (root.pairingAgent) {
            if (!root.agentCall("arm", [device.dbusPath, device.name || device.address, device.address])) {
                root.errorMessage = "Pairing is unavailable. Reopen Bluetooth or use the Bluetooth manager."
                return
            }
            root._nativePair = true
        }
        root.busyDeviceAddress = device.address || ""
        root._busyTargetConnected = true
        root._pairingPath = device.dbusPath
        root._pendingConnectDevice = device
        if (root._nativePair) {
            if (!root.agentCall("startPair", [])) {
                root.agentCall("abort", [])
                root._finishPair(device.dbusPath, false, "Could not start pairing")
            }
        } else {
            // Until the optional module is installed (or when disabled), the
            // existing default agent continues to handle native QS pairing.
            device.pair()
            root._fallbackPairStarted = device.pairing
        }
    }

    function forgetDevice(device) {
        if (device && busyDeviceAddress === "" && !root.agentBusy) device.forget()
    }

    function openSettings() {
        AppLaunchService.launchCommand(["blueman-manager"])
    }

    // The native agent owns its absolute deadline. This timer only bounds
    // compatibility pairing through the external default agent.
    Timer {
        interval: 30000
        running: root.pairingPending && !root._nativePair
        onTriggered: {
            root.cancelPairing()
            root.errorMessage = "Pairing timed out. Check the device or use the Bluetooth manager."
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
            function onPairingChanged() {
                if (!root._nativePair && modelData.dbusPath === root._pendingConnectDevice?.dbusPath && modelData.pairing) root._fallbackPairStarted = true
                root._scheduleRecompute()
            }
            function onTrustedChanged()   { root._scheduleRecompute() }
            function onBlockedChanged()   { root._scheduleRecompute() }
            function onNameChanged()      { root._scheduleRecompute() }
            function onBatteryChanged()   { root._scheduleRecompute() }
        }
        onObjectAdded: root._scheduleRecompute()
        onObjectRemoved: root._scheduleRecompute()
    }

    onEnabledChanged: _scheduleRecompute()
    on_PendingConnectDeviceChanged: if (!root._pendingConnectDevice && root._nativePair) root.agentCall("abort", [])
    Component.onCompleted: _scheduleRecompute()

    function _recompute() {
        if (!adapter || !adapter.devices || !enabled) {
            root.cancelPairing()
            connected = false
            connectedDeviceCount = 0
            pairedDevices = []
            discoveredDevices = []
            return
        }

        let count = 0
        const paired = []
        const discovered = []

        for (const d of root._devices) {
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
        pairedDevices = paired.sort((a, b) => Number(b.connected) - Number(a.connected)
            || (a.name || a.address).localeCompare(b.name || b.address))
        discoveredDevices = discovered.sort((a, b) => (a.name || a.address).localeCompare(b.name || b.address))

        const pending = root._pendingConnectDevice
        const path = root.agentValue("operationPath", "")
        if (path && !root._devices.some(device => device.dbusPath === path))
            root.agentCall("deviceRemoved", [path])
        if (pending && !root._nativePair && root._fallbackPairStarted && !pending.pairing)
            root._finishPair(pending.dbusPath, pending.paired, "Pairing failed. Check the device or use the Bluetooth manager.")

        // Clear busy state only when the busy DEVICE reached the target
        // state (or vanished) — not on unrelated recomputes.
        if (busyDeviceAddress && !_pendingConnectDevice && !root.agentBusy) {
            let busyDev = null
            for (const d of root._devices) {
                if (d && d.address === busyDeviceAddress) { busyDev = d; break }
            }
            if (!busyDev || busyDev.connected === _busyTargetConnected)
                busyDeviceAddress = ""
        }
    }

    // Never leave a stuck busy indicator if the operation silently dies.
    Timer {
        interval: 20000
        running: root.busyDeviceAddress !== "" && !root.pairingPending && !root.agentBusy
        onTriggered: {
            root.errorMessage = "The Bluetooth operation did not finish. Check the device and try again."
            root.busyDeviceAddress = ""
        }
    }
}
