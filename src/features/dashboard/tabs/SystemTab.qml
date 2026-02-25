import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Networking
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components

Item {
    id: root

    // Exclusive accordion: only one section open at a time
    property int expandedIndex: -1

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // ===== LEFT COLUMN: AUDIO (always visible) =====
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: Tokens.spacing.medium

            // Output device card
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                color: sinkMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: sinkMouseArea.containsMouse ? Theme.onSecondaryContainer : Theme.primaryContainer
                        Behavior on color { ColorAnimation { duration: Tokens.motion.duration.short4 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "volume_up"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: sinkMouseArea.containsMouse ? Theme.secondaryContainer : Theme.onPrimaryContainer
                            backgroundColor: "transparent"
                            Behavior on iconColor { ColorAnimation { duration: Tokens.motion.duration.short4 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: AudioService.defaultSink ? (AudioService.defaultSink.description || AudioService.defaultSink.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Tokens.typography.headlineSmall.size
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sinkMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sinkDialog.openDialog(AudioService.sinkNodes, AudioService.defaultSink, "Select Output Device", "output")
                }
            }

            // Input device card
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                color: sourceMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: sourceMouseArea.containsMouse ? Theme.onSecondaryContainer : Theme.tertiaryContainer
                        Behavior on color { ColorAnimation { duration: Tokens.motion.duration.short4 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "mic"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: sourceMouseArea.containsMouse ? Theme.secondaryContainer : Theme.onTertiaryContainer
                            backgroundColor: "transparent"
                            Behavior on iconColor { ColorAnimation { duration: Tokens.motion.duration.short4 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: AudioService.defaultSource ? (AudioService.defaultSource.description || AudioService.defaultSource.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Tokens.typography.headlineSmall.size
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sourceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sourceDialog.openDialog(AudioService.sourceNodes, AudioService.defaultSource, "Select Input Device", "input")
                }
            }

            // Application Volume Mixer
            MaterialCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
                radius: Tokens.shape.large

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    SectionHeader {
                        Layout.fillWidth: true
                        title: "Volume Mixer"
                        icon: "graphic_eq"
                        badgeText: AudioService.streamNodes.length > 0 ? AudioService.streamNodes.length.toString() : ""
                    }

                    ScrollableList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: ScriptModel {
                                values: AudioService.streamNodes
                            }

                            delegate: MaterialCard {
                                required property var modelData
                                property var stream: modelData
                                property string appIcon: AudioService.getAppIcon(stream)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 90
                                color: Theme.surfaceContainer
                                radius: Tokens.shape.medium

                                data: [
                                    PwObjectTracker {
                                        objects: stream ? [stream] : []
                                    }
                                ]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.spacing.small
                                    spacing: Tokens.spacing.small

                                    CircleAvatar {
                                        size: "medium"
                                        imageSource: appIcon
                                        fallbackText: stream && stream.properties && stream.properties["application.name"] ?
                                                     stream.properties["application.name"] : "AP"
                                        customRadius: 6
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            MaterialText {
                                                text: stream && stream.properties && stream.properties["application.name"] ?
                                                stream.properties["application.name"] :
                                                (stream.appName || stream.name || stream.clientName || "Application")
                                                textStyle: "labelLarge"
                                                colorRole: "onSurface"
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Item { Layout.fillWidth: true }
                                            MaterialText {
                                                text: AudioService.formatVolume(stream && stream.audio ? stream.audio.volume : null) + "%"
                                                textStyle: "labelMedium"
                                                colorRole: "onSurfaceVariant"
                                                font.weight: Font.Medium
                                                Layout.preferredWidth: 40
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }

                                        MaterialSlider {
                                            Layout.fillWidth: true
                                            enabled: !!(stream && stream.audio)
                                            from: 0; to: 1; stepSize: 0.01
                                            value: (stream && stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                            onMoved: if (stream && stream.audio) stream.audio.volume = value
                                        }
                                    }

                                    IconButton {
                                        iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                        iconSize: Tokens.typography.headlineSmall.size
                                        iconColor: (stream && stream.audio && stream.audio.muted) ?
                                                  Theme.onErrorContainer : Theme.onSurfaceVariant
                                        variant: "standard"
                                        enabled: !!(stream && stream.audio)
                                        onClicked: if (stream && stream.audio) stream.audio.muted = !stream.audio.muted
                                    }
                                }
                            }
                        }

                        EmptyState {
                            visible: AudioService.streamNodes.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            iconName: "music_off"
                            title: "No active audio streams"
                            subtitle: "Play something to see it here"
                        }
                    }
                }
            }
        }

        // ===== RIGHT COLUMN: CONNECTIVITY (accordion) =====
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: Tokens.spacing.small

            ScrollableList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                // --- WiFi Section ---
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: "WiFi"
                    icon: NetworkService.icon
                    statusText: NetworkService.wifiEnabled
                        ? (NetworkService.currentNetwork || "Not connected")
                        : "Disabled"
                    statusColor: NetworkService.currentNetwork !== "" ? Theme.primary : Theme.onSurfaceVariant
                    toggleEnabled: true
                    toggleChecked: NetworkService.wifiEnabled
                    onToggleClicked: NetworkService.toggleWifi()
                    expanded: root.expandedIndex === 0
                    onHeaderClicked: root.expandedIndex = root.expandedIndex === 0 ? -1 : 0

                    ColumnLayout {
                        width: parent.width
                        spacing: Tokens.spacing.small
                        Layout.topMargin: Tokens.spacing.small

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

                        // Scan button
                        MaterialButton {
                            Layout.fillWidth: true
                            visible: NetworkService.wifiEnabled
                            text: NetworkService.scanning ? "Scanning..." : "Scan"
                            variant: "outlined"
                            onClicked: {
                                if (NetworkService.scanning) {
                                    NetworkService.stopScan()
                                } else {
                                    NetworkService.startScan()
                                }
                            }
                        }

                        EmptyState {
                            visible: !NetworkService.wifiEnabled
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            iconName: "wifi_off"
                            title: "WiFi is disabled"
                            subtitle: "Toggle the switch to enable"
                            iconContainerSize: 56
                            iconSize: 32
                        }
                    }
                }

                // --- Bluetooth Section ---
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: "Bluetooth"
                    icon: BluetoothService.icon
                    statusText: {
                        if (!BluetoothService.enabled) return "Disabled"
                        if (BluetoothService.connectedDeviceCount > 0)
                            return BluetoothService.connectedDeviceCount + " connected"
                        return "No devices"
                    }
                    statusColor: BluetoothService.connectedDeviceCount > 0 ? Theme.primary : Theme.onSurfaceVariant
                    toggleEnabled: true
                    toggleChecked: BluetoothService.enabled
                    onToggleClicked: BluetoothService.toggle()
                    expanded: root.expandedIndex === 1
                    onHeaderClicked: root.expandedIndex = root.expandedIndex === 1 ? -1 : 1

                    ColumnLayout {
                        width: parent.width
                        spacing: Tokens.spacing.small
                        Layout.topMargin: Tokens.spacing.small

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
                                Layout.fillWidth: true
                                headline: modelData.name || modelData.address
                                supportingText: modelData.connected ? "Connected" : "Disconnected"
                                leadingImageSource: modelData.icon ? Quickshell.iconPath(modelData.icon, "bluetooth") : ""
                                leadingIcon: !modelData.icon ? modelData.iconName : ""
                                leadingIconColor: modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                                trailingSupportingText: modelData.battery >= 0 ? Math.round(modelData.battery * 100) + "%" : ""
                                margin: Tokens.spacing.small

                                trailingContent: [
                                    IconButton {
                                        iconName: modelData.connected ? "link_off" : "link"
                                        variant: "standard"
                                        onClicked: {
                                            if (modelData.connected) {
                                                BluetoothService.disconnectDevice(modelData.device)
                                            } else {
                                                BluetoothService.connectDevice(modelData.device)
                                            }
                                        }
                                    }
                                ]
                            }
                        }

                        // Scan button
                        MaterialButton {
                            Layout.fillWidth: true
                            visible: BluetoothService.enabled
                            text: BluetoothService.scanning ? "Scanning..." : "Scan for devices"
                            variant: "outlined"
                            onClicked: {
                                if (BluetoothService.scanning) {
                                    BluetoothService.stopScan()
                                } else {
                                    BluetoothService.startScan()
                                }
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
                                Layout.fillWidth: true
                                headline: modelData.name || modelData.address
                                leadingImageSource: modelData.icon ? Quickshell.iconPath(modelData.icon, "bluetooth") : ""
                                leadingIcon: !modelData.icon ? modelData.iconName : ""
                                leadingIconColor: Theme.onSurfaceVariant
                                margin: Tokens.spacing.small

                                trailingContent: [
                                    IconButton {
                                        iconName: "add_link"
                                        variant: "standard"
                                        onClicked: {
                                            console.log("Pairing with device:", modelData.name || modelData.address)
                                            BluetoothService.pairDevice(modelData.device)
                                        }
                                    }
                                ]
                            }
                        }

                        EmptyState {
                            visible: !BluetoothService.enabled
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            iconName: "bluetooth_disabled"
                            title: "Bluetooth is disabled"
                            subtitle: "Toggle the switch to enable"
                            iconContainerSize: 56
                            iconSize: 32
                        }
                    }
                }

                // --- VPN Section ---
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: "VPN"
                    icon: VPNService.icon
                    statusText: VPNService.connected
                        ? "Connected — " + VPNService.activeVPN
                        : "Disconnected"
                    statusColor: VPNService.connected ? Theme.primary : Theme.onSurfaceVariant
                    expanded: root.expandedIndex === 2
                    onHeaderClicked: root.expandedIndex = root.expandedIndex === 2 ? -1 : 2

                    ColumnLayout {
                        width: parent.width
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: VPNService.availableVPNs

                            delegate: ListItem {
                                required property var modelData
                                Layout.fillWidth: true
                                headline: modelData
                                supportingText: modelData === VPNService.activeVPN ? "Active" : ""
                                leadingIcon: modelData === VPNService.activeVPN ? "vpn_lock" : "vpn_key"
                                leadingIconColor: modelData === VPNService.activeVPN ? Theme.primary : Theme.onSurfaceVariant
                                margin: Tokens.spacing.small

                                trailingContent: [
                                    IconButton {
                                        iconName: modelData === VPNService.activeVPN ? "link_off" : "link"
                                        variant: "standard"
                                        onClicked: {
                                            if (modelData === VPNService.activeVPN) {
                                                VPNService.disconnect()
                                            } else {
                                                VPNService.connect(modelData)
                                            }
                                        }
                                    }
                                ]
                            }
                        }

                        EmptyState {
                            visible: VPNService.availableVPNs.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            iconName: "vpn_key_off"
                            title: "No VPN profiles"
                            subtitle: "Configure VPN in network settings"
                            iconContainerSize: 56
                            iconSize: 32
                        }
                    }
                }

                // --- Ethernet Section ---
                CollapsibleSection {
                    Layout.fillWidth: true
                    title: "Ethernet"
                    icon: EthernetService.icon
                    statusText: EthernetService.connected
                        ? EthernetService.interfaceName + " — " + EthernetService.ipAddress
                        : "Disconnected"
                    statusColor: EthernetService.connected ? Theme.primary : Theme.onSurfaceVariant
                    expanded: root.expandedIndex === 3
                    onHeaderClicked: root.expandedIndex = root.expandedIndex === 3 ? -1 : 3

                    ColumnLayout {
                        width: parent.width
                        spacing: Tokens.spacing.small
                        Layout.topMargin: Tokens.spacing.small

                        Repeater {
                            model: [
                                { label: "Interface", value: EthernetService.interfaceName },
                                { label: "IP Address", value: EthernetService.ipAddress },
                                { label: "Gateway", value: EthernetService.gateway },
                                { label: "Speed", value: EthernetService.speed }
                            ]

                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.leftMargin: Tokens.spacing.small
                                Layout.rightMargin: Tokens.spacing.small

                                MaterialText {
                                    text: modelData.label
                                    textStyle: "labelMedium"
                                    colorRole: "onSurfaceVariant"
                                }
                                Item { Layout.fillWidth: true }
                                MaterialText {
                                    text: modelData.value || "—"
                                    textStyle: "bodyMedium"
                                    colorRole: "onSurface"
                                }
                            }
                        }

                        EmptyState {
                            visible: !EthernetService.connected
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            iconName: "lan_disconnect"
                            title: "No wired connection"
                            subtitle: "Connect an Ethernet cable"
                            iconContainerSize: 56
                            iconSize: 32
                        }
                    }
                }
            }
        }
    }

    // ===== WiFi Password Dialog =====
    Dialog {
        id: wifiPasswordDialog
        anchors.fill: parent
        dialogWidth: 380
        dialogHeight: 220

        property string targetSSID: ""
        property var targetNetwork: null

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

            // Password field
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: Tokens.shape.small
                color: Theme.surfaceContainerHighest
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? Theme.primary : Theme.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.rightMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    TextInput {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        echoMode: showPasswordToggle.checked ? TextInput.Normal : TextInput.Password
                        font.family: Tokens.typography.fontFamily
                        font.pointSize: Tokens.typography.bodyLarge.size
                        color: Theme.onSurface
                        clip: true
                    }

                    IconButton {
                        id: showPasswordToggle
                        property bool checked: false
                        iconName: checked ? "visibility_off" : "visibility"
                        variant: "standard"
                        onClicked: checked = !checked
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Item { Layout.fillWidth: true }

                MaterialButton {
                    text: "Cancel"
                    variant: "text"
                    onClicked: {
                        passwordInput.text = ""
                        wifiPasswordDialog.close()
                    }
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

    // ===== Audio Device Selection Dialogs =====
    DeviceSelectionDialog {
        id: sinkDialog
        anchors.fill: parent
        onDeviceSelected: (device) => AudioService.setDefaultSink(device)
    }

    DeviceSelectionDialog {
        id: sourceDialog
        anchors.fill: parent
        onDeviceSelected: (device) => AudioService.setDefaultSource(device)
    }
}
