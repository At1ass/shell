import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback

ColumnLayout {
    spacing: Tokens.spacing.small

    ScrollableList {
        visible: VPNService.availableVPNs.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        Repeater {
            model: VPNService.availableVPNs

            delegate: ListItem {
                required property var modelData
                Layout.fillWidth: true
                headline: modelData
                supportingText: {
                    if (VPNService.busyVPN === modelData) {
                        return modelData === VPNService.activeVPN ? "Disconnecting..." : "Connecting..."
                    }
                    if (modelData === VPNService.activeVPN) return "Active"
                    return ""
                }
                leadingIcon: modelData === VPNService.activeVPN ? "vpn_lock" : "vpn_key"
                leadingIconColor: modelData === VPNService.activeVPN ? Theme.primary : Theme.onSurfaceVariant
                margin: Tokens.spacing.small
                enabled: !VPNService.busy

                trailingContent: [
                    IconButton {
                        iconName: modelData === VPNService.activeVPN ? "link_off" : "link"
                        variant: "standard"
                        enabled: !VPNService.busy
                        onClicked: {
                            if (modelData === VPNService.activeVPN)
                                VPNService.disconnect()
                            else
                                VPNService.connect(modelData)
                        }
                    }
                ]
            }
        }
    }

    EmptyState {
        visible: VPNService.availableVPNs.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        iconName: "vpn_key_off"
        title: "No VPN profiles"
        subtitle: "Configure VPN in network settings"
        iconContainerSize: 56
        iconSize: Tokens.iconSize.extraLarge
    }
}
