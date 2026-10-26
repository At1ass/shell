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
    readonly property var wifiDevice: _findWifiDevice()
    readonly property var networks: wifiDevice ? wifiDevice.networks.values : []

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

    // Toggle WiFi
    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Activate a saved profile; missing credentials may require an external agent.
    function connectToNetwork(network) {
        if (!network || network.stateChanging || root.newConnectionBusy) return
        root.clearError()
        network.connect()
    }

    // QS 0.3.2 passes the PSK directly to NetworkManager over D-Bus. Retain
    // only the target, never the password; serialize writes until activation
    // reaches a terminal state or the bounded fallback deadline expires.
    function connectToNewNetwork(network, password) {
        if (!network || network.connected || network.stateChanging || root.newConnectionBusy || !password) return
        if (![WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security)) return
        root.clearError()
        root._pskActivationStarted = false
        root._pendingPskNetwork = network
        network.connectWithPsk(password)
    }

    Connections {
        target: root._pendingPskNetwork
        function onConnectedChanged() {
            if (root._pendingPskNetwork?.connected) root._pendingPskNetwork = null
        }
        function onStateChangingChanged() {
            const network = root._pendingPskNetwork
            if (!network) return
            if (network.stateChanging) root._pskActivationStarted = true
            else if (root._pskActivationStarted) root._pendingPskNetwork = null
        }
        function onConnectionFailed() { root._pendingPskNetwork = null }
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

    // Start scanning for networks
    function startScan() {
        if (wifiDevice) wifiDevice.scannerEnabled = true
    }

    // Stop scanning
    function stopScan() {
        if (wifiDevice) wifiDevice.scannerEnabled = false
    }

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

    Instantiator {
        model: ScriptModel { values: root.networks }
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root.errorMessage = reason === ConnectionFailReason.NoSecrets
                    ? "Authentication is required. Open the network menu to retry or edit the profile."
                    : "Could not connect: " + ConnectionFailReason.toString(reason)
                if (!GlobalStates.connectionsOpen) ToastService.error(root.errorMessage)
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
