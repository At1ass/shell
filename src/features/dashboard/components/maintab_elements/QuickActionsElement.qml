import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    id: quickActions
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        spacing: Tokens.spacing.extraSmall

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rows: 4
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
                        active: () => IdleInhibitorService.inhibit,
                        tooltip: () => IdleInhibitorService.inhibit ? "Caffeine Mode Active" : "Caffeine Mode Inactive",
                        action: () => IdleInhibitorService.toggleInhibit()
                    },
                    // Row 2
                    {
                        icon: "do_not_disturb_on",
                        active: () => NotificationService.doNotDisturb,
                        tooltip: () => NotificationService.doNotDisturb ? "Do Not Disturb Active" : "Do Not Disturb",
                        action: () => NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                    },
                    {
                        icon: "screenshot_region",
                        active: () => false,
                        tooltip: "Screenshot (Annotate)",
                        action: () => ScreenshotService.takeScreenshotSwappy()
                    },
                    {
                        icon: "sports_esports",
                        active: () => GamingModeService.gamingModeActive,
                        tooltip: () => GamingModeService.gamingModeActive ? "Gaming Mode Active" : "Gaming Mode",
                        action: () => GamingModeService.toggleGamingMode()
                    },
                    {
                        icon: "nightlight",
                        active: () => NightLightService.enabled,
                        tooltip: () => NightLightService.enabled ? "Night Light Active" : "Night Light",
                        action: () => NightLightService.toggle()
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.shape.small

                    // Evaluate function or use value directly
                    readonly property bool isActive: typeof modelData.active === "function" ?
                                                    modelData.active() : modelData.active
                    readonly property string iconName: typeof modelData.icon === "function" ?
                                                      modelData.icon() : modelData.icon
                    readonly property string tooltipText: typeof modelData.tooltip === "function" ?
                                                         modelData.tooltip() : (modelData.tooltip || "")

                    color: isActive ? Theme.primaryContainer : Theme.surfaceContainerHighest

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: parent.iconName
                        iconColor: parent.isActive ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                        fontSize: Tokens.typography.titleMedium.size
                        backgroundColor: "transparent"

                        Behavior on iconColor {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }
                    }

                    StateLayer {
                        layerColor: parent.isActive ? Theme.onPrimaryContainer : Theme.onSurface
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

                    // QtQuick.Controls ToolTip — no tooltipManager available
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
