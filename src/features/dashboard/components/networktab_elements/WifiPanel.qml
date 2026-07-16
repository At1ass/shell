import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.inputs

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        ScrollableList {
            visible: NetworkService.wifiEnabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Repeater {
                model: NetworkService.networks

                delegate: ListItem {
                    required property var modelData
                    Layout.fillWidth: true
                    headline: modelData.name || "Hidden Network"
                    supportingText: {
                        if (modelData.connected) return "Connected"
                        if (modelData.stateChanging) return "Connecting..."
                        const sec = NetworkService.securityText(modelData.security)
                        return sec !== "Open" ? sec : ""
                    }
                    leadingIcon: NetworkService.signalIcon(modelData.signalStrength)
                    leadingIconColor: modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                    trailingIcon: {
                        if (modelData.connected) return "check_circle"
                        if (modelData.security !== WifiSecurityType.Open && !modelData.known) return "lock"
                        return ""
                    }
                    trailingIconColor: modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                    margin: Tokens.spacing.small

                    onClicked: {
                        if (modelData.connected) {
                            NetworkService.disconnectNetwork(modelData)
                        } else if (modelData.known) {
                            NetworkService.connectToNetwork(modelData)
                        } else if (modelData.security !== WifiSecurityType.Open) {
                            wifiPasswordDialog.targetNetwork = modelData
                            wifiPasswordDialog.targetSSID = modelData.name
                            wifiPasswordDialog.open()
                        } else {
                            NetworkService.connectToNetwork(modelData)
                        }
                    }
                }
            }
        }

        EmptyState {
            visible: !NetworkService.wifiEnabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "wifi_off"
            title: "WiFi is disabled"
            subtitle: "Toggle the switch to enable"
            iconContainerSize: 56
            iconSize: 32
        }

    MaterialButton {
        Layout.fillWidth: true
        visible: NetworkService.wifiEnabled
        text: NetworkService.scanning ? "Scanning..." : "Scan"
        variant: "outlined"
        onClicked: {
            if (NetworkService.scanning) NetworkService.stopScan()
            else NetworkService.startScan()
        }
    }
    }

    // WiFi Password Dialog
    Dialog {
        id: wifiPasswordDialog
        anchors.fill: parent
        dialogWidth: 380
        dialogHeight: 220

        property string targetSSID: ""
        property var targetNetwork: null

        // Wipe the plaintext password on EVERY close path (scrim click,
        // Escape, buttons) — not just the button handlers.
        onVisibleChanged: {
            if (!visible) {
                passwordInput.text = ""
                passwordInput.password = true
                targetNetwork = null
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            MaterialText {
                text: "Connect to " + wifiPasswordDialog.targetSSID
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Medium
            }

            MaterialTextField {
                id: passwordInput
                Layout.fillWidth: true
                password: true
                placeholderText: "Password"
                trailingIcon: passwordInput.password ? "visibility" : "visibility_off"
                onTrailingClicked: passwordInput.password = !passwordInput.password
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Item { Layout.fillWidth: true }
                MaterialButton {
                    text: "Cancel"
                    variant: "text"
                    onClicked: { passwordInput.text = ""; wifiPasswordDialog.close() }
                }
                MaterialButton {
                    text: "Connect"
                    variant: "filled"
                    enabled: passwordInput.text.length >= 8
                    onClicked: {
                        NetworkService.connectToNewNetwork(wifiPasswordDialog.targetSSID, passwordInput.text)
                        passwordInput.text = ""
                        wifiPasswordDialog.close()
                    }
                }
            }
        }
    }
}
