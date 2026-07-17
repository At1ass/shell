pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false
    property string interfaceName: ""
    property string ipAddress: ""
    property string gateway: ""
    property string speed: ""
    // Material Symbols has no lan_disconnect glyph; settings_ethernet reads as "port, no link".
    readonly property string icon: connected ? "lan" : "settings_ethernet"

    // Refresh on demand — NetworkEventMonitor calls this on NM events.
    function refresh() {
        if (!deviceStatusProc.running) deviceStatusProc.running = true
    }

    // Query ethernet device status
    Process {
        id: deviceStatusProc
        running: true
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("EthernetService: nmcli device status failed (exit " + exitCode + ")")
        }

        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                const lines = statusCollector.text.trim().split('\n')
                let found = false

                for (const line of lines) {
                    const parts = line.split(':')
                    if (parts.length >= 3 && parts[1] === 'ethernet' && parts[2] === 'connected') {
                        found = true
                        root.interfaceName = parts[0]
                        // Fetch details for this interface
                        deviceDetailProc.command = ["nmcli", "-t", "-f",
                            "IP4.ADDRESS,IP4.GATEWAY,GENERAL.HWADDR",
                            "device", "show", parts[0]]
                        if (!deviceDetailProc.running) deviceDetailProc.running = true
                        break
                    }
                }

                if (!found) {
                    root.connected = false
                    root.interfaceName = ""
                    root.ipAddress = ""
                    root.gateway = ""
                    root.speed = ""
                }
            }
        }
    }

    // Get detailed info for the connected ethernet interface
    Process {
        id: deviceDetailProc

        onExited: (exitCode) => {
            if (exitCode !== 0)
                console.warn("EthernetService: nmcli device show failed (exit " + exitCode + ")")
        }

        stdout: StdioCollector {
            id: detailCollector
            onStreamFinished: {
                const lines = detailCollector.text.trim().split('\n')

                let gotAddress = false
                for (const line of lines) {
                    const sep = line.indexOf(':')
                    if (sep === -1) continue
                    const key = line.substring(0, sep)
                    const value = line.substring(sep + 1)

                    if (key === "IP4.ADDRESS[1]") {
                        root.ipAddress = value.split('/')[0] || value
                        gotAddress = value.length > 0
                    } else if (key === "IP4.GATEWAY") {
                        root.gateway = value
                    }
                }

                // "connected" means usable: require an actual IPv4 address.
                root.connected = gotAddress
                // Defense-in-depth: interfaceName comes from nmcli (trusted)
                // but we still validate the shape before splicing it into a
                // /sys path. Linux ifnames are alnum + _ - . (max 15 chars).
                if (/^[A-Za-z0-9_.-]{1,15}$/.test(root.interfaceName)) {
                    const path = "/sys/class/net/" + root.interfaceName + "/speed"
                    if (speedFile.path === path) speedFile.reload()
                    else speedFile.path = path
                } else {
                    root.speed = ""
                }
            }
        }
    }

    // Link speed straight from sysfs — no `cat` subprocess needed.
    FileView {
        id: speedFile

        onLoaded: {
            const val = text().trim()
            root.speed = (val && val !== "-1") ? val + " Mb/s" : ""
        }

        onLoadFailed: root.speed = ""  // e.g. no permission / iface gone
    }
}
