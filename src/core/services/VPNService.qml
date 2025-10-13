pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // VPN state
    property bool connected: false
    property string activeVPN: ""
    property list<string> availableVPNs: []

    // Primary VPN connection name (user-configurable)
    readonly property string primaryVPN: "diasoft_VPN"

    // Material icon based on state
    readonly property string icon: connected ? "vpn_lock" : "vpn_key_off"

    // Toggle primary VPN
    function toggle() {
        if (connected && activeVPN === primaryVPN) {
            // Disconnect
            disconnectProc.running = true
        } else {
            // Connect to primary VPN
            connectProc.running = true
        }
    }

    // Connect to specific VPN
    function connect(vpnName) {
        specificConnectProc.command = ["nmcli", "connection", "up", vpnName]
        specificConnectProc.running = true
    }

    // Disconnect active VPN
    function disconnect() {
        disconnectProc.running = true
    }

    // Open system network settings
    function openSettings() {
        Quickshell.execDetached(["nm-connection-editor"])
    }

    // Monitor VPN connection state
    Process {
        id: vpnStateProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show", "--active"]

        stdout: StdioCollector {
            id: vpnStateCollector
            onStreamFinished: {
                const lines = vpnStateCollector.text.trim().split('\n')
                let vpnFound = false
                let vpnName = ""

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 3 && parts[1] === 'vpn' && parts[2] === 'activated') {
                        vpnFound = true
                        vpnName = parts[0]
                        break
                    }
                }

                root.connected = vpnFound
                root.activeVPN = vpnName
            }
        }
    }

    // Get list of all VPN connections
    Process {
        id: vpnListProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

        stdout: StdioCollector {
            id: vpnListCollector
            onStreamFinished: {
                const lines = vpnListCollector.text.trim().split('\n')
                const vpns = []

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 2 && parts[1] === 'vpn') {
                        vpns.push(parts[0])
                    }
                }

                root.availableVPNs = vpns
            }
        }
    }

    // Connect to primary VPN
    Process {
        id: connectProc
        command: ["nmcli", "connection", "up", root.primaryVPN]

        stdout: StdioCollector {
            onStreamFinished: {
                // Refresh state after connection attempt
                vpnStateProc.running = true
            }
        }
    }

    // Connect to specific VPN
    Process {
        id: specificConnectProc

        stdout: StdioCollector {
            onStreamFinished: {
                // Refresh state after connection attempt
                vpnStateProc.running = true
            }
        }
    }

    // Disconnect VPN
    Process {
        id: disconnectProc
        command: ["nmcli", "connection", "down", root.activeVPN]

        stdout: StdioCollector {
            onStreamFinished: {
                // Refresh state after disconnection
                vpnStateProc.running = true
            }
        }
    }

    // Periodic refresh (every 5 seconds)
    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            vpnStateProc.running = true
            vpnListProc.running = true
        }
    }
}
