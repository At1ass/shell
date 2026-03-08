import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.networktab_elements

Item {
    id: root

    property int selectedPanel: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        // Connectivity chip bar
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ConnectivityChip {
                icon: NetworkService.icon
                title: "WiFi"
                statusText: NetworkService.wifiEnabled ? (NetworkService.currentNetwork || "Not connected") : "Disabled"
                statusColor: NetworkService.currentNetwork !== "" ? Theme.primary : Theme.onSurfaceVariant
                active: root.selectedPanel === 0
                toggleEnabled: true
                toggleChecked: NetworkService.wifiEnabled
                onClicked: root.selectedPanel = 0
                onToggleClicked: NetworkService.toggleWifi()
            }

            ConnectivityChip {
                icon: BluetoothService.icon
                title: "Bluetooth"
                statusText: {
                    if (!BluetoothService.enabled) return "Disabled"
                    if (BluetoothService.connectedDeviceCount > 0)
                        return BluetoothService.connectedDeviceCount + " connected"
                    return "No devices"
                }
                statusColor: BluetoothService.connectedDeviceCount > 0 ? Theme.primary : Theme.onSurfaceVariant
                active: root.selectedPanel === 1
                toggleEnabled: true
                toggleChecked: BluetoothService.enabled
                onClicked: root.selectedPanel = 1
                onToggleClicked: BluetoothService.toggle()
            }

            ConnectivityChip {
                icon: VPNService.icon
                title: "VPN"
                statusText: VPNService.busy ? (VPNService.busyVPN + "...") : VPNService.connected ? VPNService.activeVPN : "Disconnected"
                statusColor: VPNService.connected ? Theme.primary : Theme.onSurfaceVariant
                active: root.selectedPanel === 2
                onClicked: root.selectedPanel = 2
            }

            ConnectivityChip {
                icon: EthernetService.icon
                title: "Ethernet"
                statusText: EthernetService.connected ? EthernetService.ipAddress : "Disconnected"
                statusColor: EthernetService.connected ? Theme.primary : Theme.onSurfaceVariant
                active: root.selectedPanel === 3
                onClicked: root.selectedPanel = 3
            }
        }

        // Detail panel
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedPanel

            WifiPanel {}
            BluetoothPanel {}
            VpnPanel {}
            EthernetPanel {}
        }
    }
}
