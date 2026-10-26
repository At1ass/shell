pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Networking

Singleton {
    id: root
    readonly property QtObject _deviceModel: Networking.devices
    readonly property list<NetworkDevice> _devices: _deviceModel ? (_deviceModel["values"] ?? []) : []
    readonly property WiredDevice device: {
        for (const candidate of root._devices) {
            if (candidate.type === DeviceType.Wired && candidate.connected) return candidate
        }
        return null
    }
    // NetworkManager activation determines connection state. IPv6-only,
    // link-local and local-only connections must not disappear for lacking IPv4.
    readonly property bool connected: device !== null
    readonly property string interfaceName: device?.name ?? ""
    readonly property list<string> ipv4Addresses: info.ipv4Addresses
    readonly property list<string> ipv6Addresses: info.ipv6Addresses
    readonly property string ipv4Gateway: info.ipv4Gateway
    readonly property string ipv6Gateway: info.ipv6Gateway
    readonly property bool detailsReady: info.ready
    readonly property string icon: connected ? "lan" : "settings_ethernet"
    function refresh() { info.refresh() }
    NetworkInfo { id: info; interfaceName: root.interfaceName }
}
