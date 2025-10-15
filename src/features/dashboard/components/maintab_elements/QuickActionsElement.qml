import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.extraSmall

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rows: 2
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: [
                    // Row 1
                    {
                        icon: () => NetworkService.icon,
                        active: () => NetworkService.wifiEnabled,
                        tooltip: () => NetworkService.wifiEnabled ?
                                    (NetworkService.currentNetwork || "WiFi Enabled") :
                                    "WiFi Disabled",
                        action: () => NetworkService.toggleWifi()
                    },
                    {
                        icon: () => BluetoothService.icon,
                        active: () => BluetoothService.enabled,
                        tooltip: () => BluetoothService.enabled ?
                                    (BluetoothService.connected ?
                                        `Bluetooth (${BluetoothService.connectedDeviceCount} connected)` :
                                        "Bluetooth Enabled") :
                                    "Bluetooth Disabled",
                        action: () => BluetoothService.toggle()
                    },
                    {
                        icon: () => VPNService.icon,
                        active: () => VPNService.connected,
                        tooltip: () => VPNService.connected ?
                                    `VPN Connected (${VPNService.activeVPN})` :
                                    "VPN Disconnected",
                        action: () => VPNService.toggle()
                    },
                    {
                        icon: "coffee",
                        active: () => IdleInhibitor.inhibit,
                        tooltip: () => IdleInhibitor.inhibit ? "Caffeine Mode Active" : "Caffeine Mode Inactive",
                        action: () => IdleInhibitor.toggleInhibit()
                    },
                    // Row 2
                    {
                        icon: "do_not_disturb_on",
                        active: () => false,  // Placeholder
                        tooltip: "Do Not Disturb (Coming Soon)",
                        action: () => console.log("DND toggle - not implemented yet")
                    },
                    {
                        icon: "nightlight",
                        active: () => false,  // Placeholder
                        tooltip: "Night Light (Coming Soon)",
                        action: () => console.log("Night Light toggle - not implemented yet")
                    },
                    {
                        icon: "videogame_asset",
                        active: () => false,  // Placeholder
                        tooltip: "Game Mode (Coming Soon)",
                        action: () => console.log("Game Mode toggle - not implemented yet")
                    },
                    {
                        icon: "screenshot",
                        active: () => false,  // Placeholder
                        tooltip: "Screenshot (Coming Soon)",
                        action: () => console.log("Screenshot - not implemented yet")
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Config.shape.small

                    // Evaluate function or use value directly
                    readonly property bool isActive: typeof modelData.active === "function" ?
                                                    modelData.active() : modelData.active
                    readonly property string iconName: typeof modelData.icon === "function" ?
                                                      modelData.icon() : modelData.icon
                    readonly property string tooltipText: typeof modelData.tooltip === "function" ?
                                                         modelData.tooltip() : (modelData.tooltip || "")

                    color: isActive ? Config.colors.primaryContainer : Config.colors.surfaceContainerHighest

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: parent.iconName
                        iconColor: parent.isActive ? Config.colors.onPrimaryContainer : Config.colors.onSurfaceVariant
                        fontSize: Config.typography.titleMedium.size
                        backgroundColor: "transparent"

                        Behavior on iconColor {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }
                    }

                    StateLayer {
                        layerColor: parent.isActive ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        hovered: actionMouseArea.containsMouse
                        pressed: actionMouseArea.pressed
                    }

                    MouseArea {
                        id: actionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (modelData.action) {
                                modelData.action()
                            }
                        }
                    }

                    // Tooltip (optional - если есть компонент)
                    ToolTip {
                        visible: actionMouseArea.containsMouse && parent.tooltipText !== ""
                        text: parent.tooltipText
                        delay: 500
                    }
                }
            }
        }
    }
}
