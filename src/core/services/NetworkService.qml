pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    // Retained panels stay alive when hidden; discovery must stop on close.
    Connections {
        target: GlobalStates
        function onConnectionsOpenChanged() {
            if (!GlobalStates.connectionsOpen) root.stopScan()
        }
    }


    // Native Quickshell.Networking API
    readonly property WifiDevice wifiDevice: _findWifiDevice()
    readonly property QtObject _networkModel: wifiDevice?.networks ?? null
    readonly property list<WifiNetwork> networks: _networkModel ? (_networkModel["values"] ?? []) : []

    readonly property bool wifiAvailable: root.wifiDevice !== null
    // Stable groups and names: signal-strength fluctuations never reorder rows.
    readonly property var displayNetworks: [...root.networks].sort((a, b) =>
        Number(b?.connected) - Number(a?.connected) || Number(b?.known) - Number(a?.known)
        || (a?.name || "").localeCompare(b?.name || ""))
    readonly property bool wiredConnected: {
        const devices = Networking.devices?.values ?? []
        for (const device of devices) {
            if (device?.type === DeviceType.Wired && device.connected) return true
        }
        return false
    }
    readonly property string connectionIcon: root.wiredConnected ? "lan" : root.icon
    readonly property string connectionLabel: root.wiredConnected ? "Wired connection"
        : root.currentNetwork || (root.wifiEnabled ? "Not connected" : "Wi-Fi off")
    readonly property bool newConnectionBusy: root._pendingPskNetwork !== null
    property WifiNetwork _pendingPskNetwork: null
    property bool _pskActivationStarted: false
    property bool _pskFailureSeen: false
    property int _attemptEpoch: 0
    property string _attemptName: ""
    property bool _scanRequested: false
    property WifiDevice _scanDevice: null
    // Command-only index, bounded by live watcher delegates. UI models remain
    // native/reactive; command lookup never scans the whole network list.
    property var _networkIndex: Object.create(null)
    property int _indexGeneration: 0
    readonly property bool connectionPending: root.newConnectionBusy
        || root.wifiDevice?.state === ConnectionState.Connecting
        || root.wifiDevice?.state === ConnectionState.Disconnecting
    readonly property bool wifiReady: root.wifiAvailable && root.wifiEnabled && root.wifiHardwareEnabled
        && root.wifiDevice.state !== ConnectionState.Unknown
    property string errorMessage: ""
    function clearError() { root.errorMessage = "" }

    // WiFi state
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property string currentNetwork: _findConnectedNetwork()?.name ?? ""
    readonly property real signalStrength: _findConnectedNetwork()?.signalStrength ?? 0
    readonly property bool scanning: wifiDevice ? wifiDevice.scannerEnabled : false

    // Material icon based on state
    readonly property string icon: {
        if (!wifiEnabled) return "wifi_off"
        if (currentNetwork === "") return "signal_wifi_0_bar"
        if (signalStrength >= 0.75) return "signal_wifi_4_bar"
        if (signalStrength >= 0.50) return "network_wifi_3_bar"
        if (signalStrength >= 0.25) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    function _resetAttempt() {
        ++root._attemptEpoch
        root._pendingPskNetwork = null
        root._pskActivationStarted = false
        root._pskFailureSeen = false
        root._attemptName = ""
        root.clearError()
    }
    onWifiEnabledChanged: { root._resetAttempt(); root._scheduleScan() }
    onWifiHardwareEnabledChanged: { root._resetAttempt(); root._scheduleScan() }
    onWifiDeviceChanged: {
        if (root._scanDevice) root._scanDevice.scannerEnabled = false
        root._scanDevice = null
        root._resetAttempt()
        root._scheduleScan()
    }
    onCurrentNetworkChanged: if (root.currentNetwork !== "") root.clearError()

    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled }

    function _networkKey(name, interfaceName) { return interfaceName + "\u0000" + name }
    function _indexedNetwork(key) { return root._networkIndex[key]?.watcher?.modelData ?? null }
    function _unindexNetwork(key, generation) {
        if (root._networkIndex[key]?.generation === generation) delete root._networkIndex[key]
    }
    // Resolve the current model entry after radio/model replacement. A dialog
    // may still hold a previous entry with the same stable SSID/interface key.
    function _resolveNetwork(network) {
        if (!network || !root.wifiReady) return null
        if (!network.device || network.device.name !== root.wifiDevice.name) return null
        const current = root._indexedNetwork(root._networkKey(network.name, network.device.name))
        // QS hides unknown networks when discovery stops, even though their
        // native QObject remains valid. A selected password-dialog target must
        // still be usable after that deadline; replaced visible entries win.
        return current ?? (network.device.state !== ConnectionState.Unknown ? network : null)
    }
    function _prepareAttempt(network) {
        const current = root._resolveNetwork(network)
        if (!current) {
            root.errorMessage = "The network is not available. Refresh networks and try again."
            return null
        }
        ++root._attemptEpoch
        root._attemptName = current.name
        root.clearError()
        // Explicit retries refresh discovery even if its previous UI deadline
        // elapsed. Normal closing/section changes still release the scan lease.
        if (GlobalStates.connectionsOpen && GlobalStates.connectionsSection === "wifi") root.startScan()
        return current
    }

    // Activate a saved profile; missing credentials may require an external agent.
    function connectToNetwork(network) {
        if (!network || network.stateChanging || root.newConnectionBusy) return
        const current = root._prepareAttempt(network)
        if (current && !current.stateChanging) current.connect()
    }

    // QS 0.3.2 passes the PSK directly to NetworkManager over D-Bus. Retain
    // only the target, never the password; serialize writes until activation
    // reaches a terminal state or the bounded fallback deadline expires.
    function connectToNewNetwork(network, password) {
        if (!network || network.connected || network.stateChanging || root.newConnectionBusy || !password) return false
        if (![WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)) return false
        const current = root._prepareAttempt(network)
        if (!current || current.connected || current.stateChanging) return false
        root._pskActivationStarted = false
        root._pskFailureSeen = false
        root._pendingPskNetwork = current
        current.connectWithPsk(password)
        return true
    }

    function _settlePsk() {
        const network = root._pendingPskNetwork
        if (!network) return
        if (network.connected) {
            root._pendingPskNetwork = null
            root.clearError()
        } else if (!network.stateChanging && root.wifiDevice?.state !== ConnectionState.Disconnecting
                && (root._pskActivationStarted || root._pskFailureSeen)) {
            root._pendingPskNetwork = null
        }
    }
    Connections {
        target: root._pendingPskNetwork
        function onConnectedChanged() { Qt.callLater(root._settlePsk) }
        function onStateChangingChanged() {
            if (root._pendingPskNetwork?.stateChanging) root._pskActivationStarted = true
            Qt.callLater(root._settlePsk)
        }
        function onConnectionFailed(reason) {
            root._reportFailure(root._pendingPskNetwork, reason)
            root._pskFailureSeen = true
            // Failure can precede the terminal state notification. Do not let
            // a replacement attempt race the old activation's teardown.
            Qt.callLater(root._settlePsk)
        }
    }
    Timer {
        interval: 120000
        running: root.newConnectionBusy
        onTriggered: {
            // Native settings-write failures are only logged by QS 0.3.2.
            // Bound the UI wait even if activation never starts.
            root._pendingPskNetwork = null
            root.errorMessage = "The connection did not finish. Check the network or open the connection editor."
            if (!GlobalStates.connectionsOpen) ToastService.error(root.errorMessage)
        }
    }

    // Disconnect from a network
    function disconnectNetwork(network) {
        if (!network || network.stateChanging) return
        root.clearError()
        network.disconnect()
    }

    // Forget a saved network
    function forgetNetwork(network) {
        if (network && !network.stateChanging) network.forget()
    }

    function _scheduleScan() { Qt.callLater(root._syncScan) }
    function _syncScan() {
        root._scanDevice = root.wifiDevice
        const wanted = root._scanRequested && root.wifiReady
        if (root._scanDevice && root._scanDevice.scannerEnabled !== wanted)
            root._scanDevice.scannerEnabled = wanted
    }
    Connections {
        target: root.wifiDevice
        function onStateChanged() {
            if (root.wifiDevice?.state === ConnectionState.Unknown) root._resetAttempt()
            root._scheduleScan()
            Qt.callLater(root._settlePsk)
        }
    }
    // A request survives the native adapter's Unknown -> Disconnected startup
    // transition. It is released by section close, Stop searching or deadline.
    function startScan() { root._scanRequested = true; root._scheduleScan() }
    function stopScan() { root._scanRequested = false; root._scheduleScan() }

    // Open system network settings
    function openSettings() {
        AppLaunchService.launchCommand(["nm-connection-editor"])
    }

    // Get signal icon name for a given strength (0.0-1.0)
    function signalIcon(strength) {
        if (strength >= 0.75) return "signal_wifi_4_bar"
        if (strength >= 0.50) return "network_wifi_3_bar"
        if (strength >= 0.25) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    // Get security display text
    function securityText(securityType) {
        return WifiSecurityType.toString(securityType)
    }

    function _reportFailure(network, reason) {
        if (!network || !root.wifiReady) return
        const name = network.name
        const interfaceName = network.device?.name ?? root.wifiDevice?.name ?? ""
        const personal = [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)
        const epoch = root._attemptEpoch
        Qt.callLater(() => {
            // Keep only stable keys across deferred delivery: the old QObject
            // may already have been replaced or destroyed by a radio reset.
            const current = root._indexedNetwork(root._networkKey(name, interfaceName))
            if (epoch !== root._attemptEpoch || !root.wifiReady || current?.connected
                    || (root._attemptName !== "" && root._attemptName !== name)) return
            if (reason === ConnectionFailReason.NoSecrets)
                root.errorMessage = "A password is required or was rejected. Enter it again or edit the profile."
            else if (reason === ConnectionFailReason.WifiAuthTimeout)
                root.errorMessage = "Authentication timed out. Check the password and signal, then retry."
            else if (reason === ConnectionFailReason.WifiNetworkLost)
                root.errorMessage = personal
                    ? "Network unavailable or authentication timed out. Check the password and signal, then retry."
                    : "The network is unavailable. Refresh networks and try again."
            else root.errorMessage = "Could not connect: " + ConnectionFailReason.toString(reason)
            if (!GlobalStates.connectionsOpen) ToastService.error(root.errorMessage)
        })
    }
    Instantiator {
        model: ScriptModel { values: Array.from(root.networks) }
        delegate: QtObject {
            id: watcher
            required property WifiNetwork modelData
            readonly property string networkKey: root._networkKey(modelData?.name ?? "",
                modelData?.device?.name ?? root.wifiDevice?.name ?? "")
            property string registeredKey: ""
            property int generation: 0
            function reindex() {
                root._unindexNetwork(registeredKey, generation)
                registeredKey = networkKey
                if (!modelData) return
                generation = ++root._indexGeneration
                root._networkIndex[registeredKey] = {watcher: watcher, generation: generation}
            }
            onNetworkKeyChanged: reindex()
            Component.onCompleted: reindex()
            Component.onDestruction: root._unindexNetwork(registeredKey, generation)
            property Connections networkSignals: Connections {
                target: watcher.modelData
                function onConnectionFailed(reason) {
                    const pending = root._pendingPskNetwork
                    // The owned request also observes hidden targets; let that
                    // watcher deliver its error once instead of two toasts.
                    if (pending && pending.name === watcher.modelData?.name
                            && pending.device?.name === watcher.modelData?.device?.name) return
                    root._reportFailure(watcher.modelData, reason)
                }
                function onConnectedChanged() { if (watcher.modelData?.connected) root.clearError() }
            }
        }
    }

    // Find the first WiFi device. Networking.devices is an UntypedObjectModel:
    // it exposes items via `values`, never via array indexing.
    function _findWifiDevice() {
        const devs = Networking.devices?.values ?? []
        for (const d of devs) {
            if (d?.type === DeviceType.Wifi) return d
        }
        return null
    }

    // Find the currently connected network
    function _findConnectedNetwork() {
        for (const n of networks) {
            if (n?.connected) return n
        }
        return null
    }
}
