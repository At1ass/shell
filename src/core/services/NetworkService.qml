pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // Native Quickshell.Networking API
    readonly property var wifiDevice: _findWifiDevice()
    readonly property var networks: wifiDevice ? wifiDevice.networks : null

    // WiFi state
    property bool wifiEnabled: Networking.wifiEnabled
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
        root.wifiEnabled = Networking.wifiEnabled
    }

    // Connect to a known network (NM already has credentials)
    function connectToNetwork(network) {
        network.connect()
    }

    // Connect to a new network with password (only place nmcli is needed)
    function connectToNewNetwork(ssid, password) {
        newConnectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        newConnectProc.running = true
    }

    // Disconnect from a network
    function disconnectNetwork(network) {
        network.disconnect()
    }

    // Forget a saved network
    function forgetNetwork(network) {
        network.forget()
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
        Quickshell.execDetached(["nm-connection-editor"])
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

    // Process for connecting to new networks with password
    Process {
        id: newConnectProc

        stdout: StdioCollector {
            onStreamFinished: {
                // Connection attempt finished; native API updates state automatically
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err) console.warn("NetworkService: nmcli connect error:", err)
            }
        }
    }

    // Find the first WiFi device
    function _findWifiDevice() {
        if (!Networking.devices) return null
        for (let i = 0; i < Networking.devices.length; i++) {
            if (Networking.devices[i].type === DeviceType.Wifi) return Networking.devices[i]
        }
        return null
    }

    // Find the currently connected network
    function _findConnectedNetwork() {
        if (!networks) return null
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected) return networks[i]
        }
        return null
    }

    // Keep wifiEnabled in sync with the native property
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root.wifiEnabled = Networking.wifiEnabled
        }
    }
}
