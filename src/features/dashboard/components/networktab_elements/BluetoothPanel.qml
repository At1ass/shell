pragma ComponentBehavior: Bound

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

    // Discovery must not outlive the panel (tab switch / dashboard close
    // otherwise leaves BT discovery churning forever).
    Component.onDestruction: BluetoothService.stopScan()

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
                id: btRow
                required property var modelData
                readonly property bool isBusy: BluetoothService.busyDeviceAddress === btRow.modelData.address
                Layout.fillWidth: true
                headline: btRow.modelData.name || btRow.modelData.address
                supportingText: {
                    if (btRow.isBusy && !btRow.modelData.connected) return "Connecting..."
                    if (btRow.isBusy && btRow.modelData.connected) return "Disconnecting..."
                    return btRow.modelData.connected ? "Connected" : "Disconnected"
                }
                leadingImageSource: btRow.modelData.icon ? Quickshell.iconPath(btRow.modelData.icon, "bluetooth") : ""
                leadingIcon: !btRow.modelData.icon ? btRow.modelData.iconName : ""
                leadingIconColor: btRow.modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                trailingSupportingText: btRow.modelData.battery >= 0 ? Math.round(btRow.modelData.battery * 100) + "%" : ""
                margin: Tokens.spacing.small

                trailingContent: [
                    IconButton {
                        iconName: btRow.modelData.connected ? "link_off" : "link"
                        variant: "standard"
                        enabled: !btRow.isBusy
                        onClicked: {
                            if (btRow.modelData.connected)
                                BluetoothService.disconnectDevice(btRow.modelData.device)
                            else
                                BluetoothService.connectDevice(btRow.modelData.device)
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
                id: btPairRow
                required property var modelData
                readonly property bool isBusy: BluetoothService.busyDeviceAddress === btPairRow.modelData.address
                Layout.fillWidth: true
                headline: btPairRow.modelData.name || btPairRow.modelData.address
                supportingText: btPairRow.isBusy ? "Pairing..." : ""
                leadingImageSource: btPairRow.modelData.icon ? Quickshell.iconPath(btPairRow.modelData.icon, "bluetooth") : ""
                leadingIcon: !btPairRow.modelData.icon ? btPairRow.modelData.iconName : ""
                leadingIconColor: Theme.onSurfaceVariant
                margin: Tokens.spacing.small

                trailingContent: [
                    IconButton {
                        iconName: "add_link"
                        variant: "standard"
                        enabled: !btPairRow.isBusy
                        onClicked: BluetoothService.pairDevice(btPairRow.modelData.device)
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
