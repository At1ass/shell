import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.src.ui.containers
import qs.src.core.config
import qs.src.ui.base
import qs.src.core.services
import ".." as Panel

// Rectangle {
MaterialCard {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: 140
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    property bool vpnToggled: false

    Process {
        id: vpnConnectionCheck
        running: true

        command: ["sh", "-c", "nmcli connection show --active | grep vpn"]//, Config.vpnName]

        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })

        stdout: StdioCollector {
            id: vpnCheckCollector
            onStreamFinished: {
                console.log("VPN check output:", this.text);
                if (this.text.trim().length > 0) {
                    vpn.toggled = true;
                } else {
                    vpn.toggled = false;
                }
                vpnConnectionCheck.running = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                console.log("VPN check err:", this.text);
                // vpn.toggled = vpnCheckCollector.text.trim().length > 0;
                vpnConnectionCheck.running = false;
            }
        }
    }

    Process {
        id: vpnConnectionToggle
        running: false
        command: ["nmcli", "connection", !vpn.toggled ? "up" : "down" , Config.vpnName]

        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })

        stdout: StdioCollector {
            id: vpnCollector
            onStreamFinished: {
                console.log("VPN command output:", vpnCollector.text);
                vpnConnectionToggle.running = false;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        // First row - Uptime (left) and Time+Date (right)
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            MaterialText {
                text: "Uptime: " + DateTime.uptime
                textStyle: "bodyMedium"
                colorRole: "onSurface"
                Layout.alignment: Qt.AlignTop
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: Config.spacing.extraSmall
                Layout.alignment: Qt.AlignTop

                MaterialText {
                    text: DateTime.time
                    textStyle: "headlineSmall"
                    colorRole: "onSurface"
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }

                MaterialText {
                    text: DateTime.date
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Third row - Quick toggle buttons (centered, no label)
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Config.spacing.medium

            Panel.QuickToggle {
                id: vpn
                toggleIcon: toggled ? "lock" : "lock_open"
                toggled: false // TODO: Connect to Network service
                onClicked: {
                    vpnConnectionToggle.running = true;
                    toggled = !toggled;
                    console.log("Vpn toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: "wifi"
                toggled: true // TODO: Connect to Network service
                onClicked: {
                    toggled = !toggled;
                    console.log("WiFi toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: "bluetooth"
                toggled: false // TODO: Connect to Bluetooth service
                onClicked: {
                    toggled = !toggled;
                    console.log("Bluetooth toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: "notifications" // Do Not Disturb
                toggled: false // TODO: Connect to Notification service
                onClicked: {
                    toggled = !toggled;
                    console.log("DND toggled:", toggled);
                }
            }

            Panel.QuickToggle {
                toggleIcon: toggled ? "dark_mode" : "light_mode" // Dark Mode
                toggled: GlobalStates.darkMode //
                onClicked: {
                    GlobalStates.darkMode = !GlobalStates.darkMode;
                    console.log("Dark mode toggled:", toggled);
                }
            }
            Panel.QuickToggle {
                toggleIcon: "local_cafe" // Dark Mode
                toggled: GlobalStates.inhibit //
                onClicked: {
                    IdleInhibitor.toggleInhibit();
                    console.log("Idle Inhibitor toggled:", toggled);
                }
            }
        }
    }
}
