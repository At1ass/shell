import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback

ColumnLayout {
    id: root
    spacing: Tokens.spacing.small

    ScrollableList {
        visible: BluetoothService.enabled
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        // Paired devices header
        MaterialText {
            visible: BluetoothService.pairedDevices.length > 0
            text: "Paired Devices"
            textStyle: "labelMedium"
            colorRole: "onSurfaceVariant"
            font.weight: Font.Medium
            Layout.bottomMargin: 2
        }

        Repeater {
            model: BluetoothService.pairedDevices

            delegate: ListItem {
                required property var modelData
                readonly property bool isBusy: BluetoothService.busyDeviceAddress === modelData.address
                Layout.fillWidth: true
                headline: modelData.name || modelData.address
                supportingText: {
                    if (isBusy && !modelData.connected) return "Connecting..."
                    if (isBusy && modelData.connected) return "Disconnecting..."
                    return modelData.connected ? "Connected" : "Disconnected"
                }
                leadingImageSource: modelData.icon ? Quickshell.iconPath(modelData.icon, "bluetooth") : ""
                leadingIcon: !modelData.icon ? modelData.iconName : ""
                leadingIconColor: modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                trailingSupportingText: modelData.battery >= 0 ? Math.round(modelData.battery * 100) + "%" : ""
                margin: Tokens.spacing.small

                trailingContent: [
                    IconButton {
                        iconName: modelData.connected ? "link_off" : "link"
                        variant: "standard"
                        enabled: !isBusy
                        onClicked: {
                            if (modelData.connected)
                                BluetoothService.disconnectDevice(modelData.device)
                            else
                                BluetoothService.connectDevice(modelData.device)
                        }
                    }
                ]
            }
        }

        // Discovered devices header
        MaterialText {
            visible: BluetoothService.discoveredDevices.length > 0
            text: "Available Devices"
            textStyle: "labelMedium"
            colorRole: "onSurfaceVariant"
            font.weight: Font.Medium
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: 2
        }

        Repeater {
            model: BluetoothService.discoveredDevices

            delegate: ListItem {
                required property var modelData
                readonly property bool isBusy: BluetoothService.busyDeviceAddress === modelData.address
                Layout.fillWidth: true
                headline: modelData.name || modelData.address
                supportingText: isBusy ? "Pairing..." : ""
                leadingImageSource: modelData.icon ? Quickshell.iconPath(modelData.icon, "bluetooth") : ""
                leadingIcon: !modelData.icon ? modelData.iconName : ""
                leadingIconColor: Theme.onSurfaceVariant
                margin: Tokens.spacing.small

                trailingContent: [
                    IconButton {
                        iconName: "add_link"
                        variant: "standard"
                        enabled: !isBusy
                        onClicked: BluetoothService.pairDevice(modelData.device)
                    }
                ]
            }
        }

    }

    EmptyState {
        visible: !BluetoothService.enabled
        Layout.fillWidth: true
        Layout.fillHeight: true
        iconName: "bluetooth_disabled"
        title: "Bluetooth is disabled"
        subtitle: "Toggle the switch to enable"
        iconContainerSize: 56
        iconSize: Tokens.iconSize.extraLarge
    }

    MaterialButton {
        Layout.fillWidth: true
        visible: BluetoothService.enabled
        text: BluetoothService.scanning ? "Scanning..." : "Scan for devices"
        variant: "outlined"
        onClicked: {
            if (BluetoothService.scanning) BluetoothService.stopScan()
            else BluetoothService.startScan()
        }
    }
}
