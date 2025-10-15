pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // WiFi state
    property bool wifiEnabled: false
    property string currentNetwork: ""
    property int signalStrength: 0

    // Material icon based on state
    readonly property string icon: {
        if (!wifiEnabled) return "wifi_off"
        if (currentNetwork === "") return "signal_wifi_0_bar"
        if (signalStrength >= 75) return "signal_wifi_4_bar"
        if (signalStrength >= 50) return "network_wifi_3_bar"
        if (signalStrength >= 25) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    // Toggle WiFi
    function toggleWifi() {
        wifiToggleProc.running = true
    }

    // Open system network settings
    function openSettings() {
        Quickshell.execDetached(["nm-connection-editor"])
    }

    // Monitor WiFi state
    Process {
        id: wifiStateProc
        running: true
        command: ["nmcli", "radio", "wifi"]

        stdout: StdioCollector {
            id: wifiStateCollector
            onStreamFinished: {
                root.wifiEnabled = wifiStateCollector.text.trim() === "enabled"
            }
        }
    }

    // Monitor active connection
    Process {
        id: activeConnectionProc
        running: root.wifiEnabled
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "device", "wifi", "list"]

        stdout: StdioCollector {
            id: activeConnectionCollector
            onStreamFinished: {
                const lines = activeConnectionCollector.text.trim().split('\n')
                let found = false

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts[0] === 'yes' || parts[0] === 'да') {
                        found = true
                        root.signalStrength = parseInt(parts[1]) || 0
                        root.currentNetwork = parts[2] || ""
                        break
                    }
                }

                if (!found) {
                    root.currentNetwork = ""
                    root.signalStrength = 0
                }
            }
        }
    }

    // Toggle process
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Refresh state after toggle
                wifiStateProc.running = true
            }
        }
    }

    // Periodic refresh (every 10 seconds)
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            wifiStateProc.running = true
            if (root.wifiEnabled) {
                activeConnectionProc.running = true
            }
        }
    }
}
