pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

MaterialCard {
    id: root
    signal closeRequested()
    readonly property string section: GlobalStates.connectionsSection
    property bool findingBluetooth: false
    property WifiNetwork targetNetwork: null
    property QtObject targetDevice: null
    property string targetVpn: ""
    property string menuKind: ""
    property string menuTitle: ""
    property var menuActions: []
    property var detailLines: []
    readonly property bool modalOpen: actionDialog.visible || passwordDialog.visible || detailsDialog.visible || forgetDialog.visible || pairingDialog.visible
    readonly property bool active: GlobalStates.connectionsOpen && root.visible

    implicitWidth: AppConfig.connectionsWidth
    implicitHeight: Math.max(column.implicitHeight + Tokens.panelPadding * 2, pairingDialog.visible ? pairingDialog.desiredHeight : 0)
    color: Theme.surfaceContainer
    radius: Tokens.shape.large
    focus: true

    function reset() {
        root.findingBluetooth = false
        root.targetNetwork = null
        root.targetDevice = null
    }
    function focusInitial() {
        if (root.section === "bluetooth") bluetoothHeader.forceActiveFocus(Qt.TabFocusReason)
        else wifiHeader.forceActiveFocus(Qt.TabFocusReason)
    }
    onSectionChanged: if (section !== "bluetooth") root.findingBluetooth = false
    function toggleSection(name) { GlobalStates.connectionsSection = root.section === name ? "" : name }
    function back() {
        if (root.modalOpen) return
        if (root.findingBluetooth) { root.findingBluetooth = false; bluetoothHeader.forceActiveFocus(); return }
        if (root.section !== "") { GlobalStates.connectionsSection = ""; return }
        root.closeRequested()
    }
    Keys.onEscapePressed: event => { root.back(); event.accepted = true }
    Keys.onPressed: event => {
        if (root.modalOpen || (event.key !== Qt.Key_Down && event.key !== Qt.Key_Up)) return
        let next = root.Window.window?.activeFocusItem ?? root
        const start = next
        do {
            next = next.nextItemInFocusChain(event.key === Qt.Key_Down)
            if (!next || next === start) return
            let owner = next
            while (owner && owner !== root) owner = owner.parent
            if (owner && next.visible && next.enabled && next.activeFocusOnTab) {
                next.forceActiveFocus(Qt.TabFocusReason)
                event.accepted = true
                return
            }
        } while (next !== start)
    }

    onActiveChanged: if (!active) {
        root.findingBluetooth = false
        if (passwordDialog.visible) passwordDialog.close()
        if (actionDialog.visible) actionDialog.close()
        if (detailsDialog.visible) detailsDialog.close()
        if (forgetDialog.visible) forgetDialog.close()
    }

    // Discovery is owned by the visible expanded section, never by Dashboard.
    readonly property bool wifiDiscovery: root.active && root.section === "wifi"
        && NetworkService.wifiReady
    readonly property bool bluetoothDiscovery: root.active && root.section === "bluetooth" && root.findingBluetooth && BluetoothService.enabled
    onWifiDiscoveryChanged: {
        if (wifiDiscovery) NetworkService.startScan()
        else NetworkService.stopScan()
    }
    onBluetoothDiscoveryChanged: {
        if (bluetoothDiscovery) BluetoothService.startScan()
        else BluetoothService.stopScan()
    }
    Component.onDestruction: { NetworkService.stopScan(); BluetoothService.stopScan() }
    Timer {
        interval: 20000
        running: root.wifiDiscovery && NetworkService.scanning && !NetworkService.connectionPending
        onTriggered: NetworkService.stopScan()
    }
    Timer {
        interval: 30000
        running: root.bluetoothDiscovery && BluetoothService.scanning
        onTriggered: BluetoothService.stopScan()
    }

    function personalSecurity(network) {
        return network && [WifiSecurityType.Sae, WifiSecurityType.Wpa2Psk,
            WifiSecurityType.WpaPsk].includes(network.security)
    }
    function askPassword(network) {
        root.targetNetwork = network
        NetworkService.clearError()
        passwordField.text = ""
        passwordDialog.open()
    }
    function wifiAction(network) {
        if (!network || network.stateChanging || NetworkService.newConnectionBusy) return
        if (network.connected) { root.wifiMenu(network); return }
        NetworkService.clearError()
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe)
            NetworkService.connectToNetwork(network)
        else if (root.personalSecurity(network)) root.askPassword(network)
        else {
            root.targetNetwork = network
            root.showActions("wifi", "This network needs advanced authentication", [
                {label: "Connection details", icon: "info", action: "details"},
                {label: "Open connection editor…", icon: "open_in_new", action: "editor"}
            ])
        }
    }
    function showActions(kind, title, actions) {
        root.menuKind = kind
        root.menuTitle = title
        root.menuActions = actions
        actionDialog.open()
    }
    function wifiMenu(network) {
        if (!network) return
        root.targetNetwork = network
        root.showActions("wifi", network.name || "Hidden network", [
            {label: network.connected ? "Disconnect" : "Connect", icon: network.connected ? "link_off" : "link", action: "connect", enabled: !network.stateChanging && !NetworkService.newConnectionBusy},
            {label: "Enter password…", icon: "password", action: "password", enabled: root.personalSecurity(network) && !network.connected && !network.stateChanging && !NetworkService.newConnectionBusy},
            {label: "Connection details", icon: "info", action: "details"},
            {label: "Forget network", icon: "delete", action: "forget", enabled: network.known && !network.stateChanging},
            {label: "Edit connections…", icon: "open_in_new", action: "editor"}
        ])
    }
    function bluetoothMenu(device) {
        if (!device) return
        root.targetDevice = device
        const busy = BluetoothService.busyDeviceAddress !== ""
        root.showActions("bluetooth", device.name || device.address, [
            {label: device.connected ? "Disconnect" : "Connect", icon: device.connected ? "link_off" : "link", action: "connect", enabled: !busy},
            {label: "Device details", icon: "info", action: "details"},
            {label: "Forget device", icon: "delete", action: "forget", enabled: !busy},
            {label: "Open Bluetooth manager…", icon: "open_in_new", action: "editor"}
        ])
    }
    function runAction(action) {
        if (!action || action.enabled === false) return
        const kind = root.menuKind
        const origin = actionDialog._previousFocus
        actionDialog.close()
        if (["editor", "network-editor", "bluetooth-editor"].includes(action.action)) {
            root.closeRequested()
            if (action.action === "bluetooth-editor" || (action.action === "editor" && kind === "bluetooth")) BluetoothService.openSettings()
            else NetworkService.openSettings()
            return
        }
        if (action.action === "password") {
            if (root.targetNetwork) {
                root.askPassword(root.targetNetwork)
                passwordDialog._previousFocus = origin
            }
            return
        }
        if (action.action === "forget") { forgetDialog.open(); forgetDialog._previousFocus = origin; return }
        if (kind === "wifi") {
            const network = root.targetNetwork
            if (!network) return
            if (action.action === "details") {
                root.detailLines = ["Network: " + network.name,
                    "Status: " + (network.connected ? "Connected" : "Not connected"),
                    "Security: " + NetworkService.securityText(network.security),
                    "Signal: " + Math.round(network.signalStrength * 100) + "%"]
                detailsDialog.open()
                detailsDialog._previousFocus = origin
            } else if (network.connected) NetworkService.disconnectNetwork(network)
            else { root.wifiAction(network); if (passwordDialog.visible) passwordDialog._previousFocus = origin }
        } else if (kind === "bluetooth") {
            const device = root.targetDevice
            if (!device) return
            if (action.action === "details") {
                root.detailLines = ["Device: " + (device.name || "Unknown device"), "Address: " + device.address,
                    "Status: " + (device.connected ? "Connected" : "Paired")]
                detailsDialog.open()
                detailsDialog._previousFocus = origin
            } else if (device.connected) BluetoothService.disconnectDevice(device)
            else BluetoothService.connectDevice(device)
        } else if (kind === "ethernet") {
            root.detailLines = ["Interface: " + EthernetService.interfaceName,
                "IP address: " + (EthernetService.ipAddress || "Unavailable"),
                "Gateway: " + (EthernetService.gateway || "Unavailable")]
            detailsDialog.open()
            detailsDialog._previousFocus = origin
        } else if (kind === "vpn") {
            if (action.action === "connect") {
                if (root.targetVpn === VPNService.activeVPN) VPNService.disconnect()
                else VPNService.connect(root.targetVpn)
            }
        }
    }

    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.panelPadding
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            RowLayout {
                Layout.fillWidth: true
                MaterialText { Layout.fillWidth: true; text: "Connections"; textStyle: "titleMedium" }
                IconButton {
                    iconName: "more_horiz"
                    Accessible.name: "More connection actions"
                    onClicked: root.showActions("editors", "Connection tools", [
                        {label: "Edit network connections…", icon: "open_in_new", action: "network-editor"},
                        {label: "Bluetooth manager…", icon: "open_in_new", action: "bluetooth-editor"}
                    ])
                }
                IconButton {
                    iconName: "close"
                    Accessible.name: "Close connections"
                    onClicked: root.closeRequested()
                }
            }
            ConnectionHeader {
                id: wifiHeader
                Layout.fillWidth: true
                headline: "Wi-Fi"
                supportingText: !NetworkService.wifiAvailable ? "No adapter"
                    : !NetworkService.wifiHardwareEnabled ? "Blocked by hardware"
                    : !NetworkService.wifiEnabled ? "Off" : !NetworkService.wifiReady ? "Starting…" : root.section === "wifi" ? "" : NetworkService.currentNetwork || "Not connected"
                leadingIcon: NetworkService.icon
                expanded: root.section === "wifi"
                toggleVisible: true
                toggleChecked: NetworkService.wifiEnabled
                toggleAvailable: NetworkService.wifiAvailable && NetworkService.wifiHardwareEnabled
                onClicked: root.toggleSection("wifi")
                onToggleRequested: NetworkService.toggleWifi()
            }
            ColumnLayout {
                Layout.fillWidth: true
                // Remove the whole body from the layout when the radio is off.
                visible: root.section === "wifi" && NetworkService.wifiAvailable
                    && NetworkService.wifiHardwareEnabled && NetworkService.wifiEnabled
                spacing: Tokens.spacing.extraSmall
                Repeater {
                    model: ScriptModel { values: root.section === "wifi" && NetworkService.wifiEnabled ? NetworkService.displayNetworks : [] }
                    delegate: ConnectionRow {
                        id: wifiRow
                        required property var modelData
                        Layout.fillWidth: true
                        headline: wifiRow.modelData?.name || "Hidden network"
                        supportingText: wifiRow.modelData?.stateChanging ? (wifiRow.modelData?.connected ? "Disconnecting…" : "Connecting…") : wifiRow.modelData?.connected ? "Connected" : ""
                        badgeIcon: wifiRow.modelData?.security === WifiSecurityType.Open ? "" : "lock"
                        leadingIcon: NetworkService.signalIcon(wifiRow.modelData?.signalStrength)
                        leadingIconColor: wifiRow.modelData?.connected ? Theme.primary : Theme.onSurfaceVariant
                        busy: (wifiRow.modelData?.stateChanging ?? false) || NetworkService.newConnectionBusy
                        onClicked: root.wifiAction(wifiRow.modelData)
                        onOptionsRequested: root.wifiMenu(wifiRow.modelData)
                    }
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: NetworkService.errorMessage !== ""
                    text: NetworkService.errorMessage
                    textStyle: "bodySmall"
                    colorRole: "error"
                    wrapMode: Text.WordWrap
                }
                MaterialButton {
                    Layout.fillWidth: true
                    visible: NetworkService.wifiEnabled && NetworkService.wifiAvailable
                    text: NetworkService.scanning ? "Stop searching" : "Refresh networks"
                    variant: "text"
                    onClicked: { if (NetworkService.scanning) NetworkService.stopScan(); else NetworkService.startScan() }
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: NetworkService.wifiEnabled && NetworkService.networks.length === 0
                    text: !NetworkService.wifiReady ? "Waiting for Wi-Fi adapter…"
                        : NetworkService.scanning ? "Searching for networks…" : "No networks found"
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                }
            }
            ConnectionHeader {
                id: bluetoothHeader
                Layout.fillWidth: true
                headline: "Bluetooth"
                supportingText: !BluetoothService.adapter ? "No adapter" : !BluetoothService.enabled ? "Off"
                    : root.section === "bluetooth" ? "" : BluetoothService.connectedDeviceCount > 0 ? BluetoothService.connectedDeviceCount + " connected" : "Not connected"
                leadingIcon: BluetoothService.icon
                expanded: root.section === "bluetooth"
                toggleVisible: true
                toggleChecked: BluetoothService.enabled
                toggleAvailable: BluetoothService.adapter !== null
                onClicked: root.toggleSection("bluetooth")
                onToggleRequested: BluetoothService.toggle()
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.section === "bluetooth" && BluetoothService.adapter !== null
                    && BluetoothService.enabled
                spacing: Tokens.spacing.extraSmall
                Repeater {
                    model: ScriptModel { values: root.section === "bluetooth" && BluetoothService.enabled ? BluetoothService.pairedDevices : []; objectProp: "address" }
                    delegate: ConnectionRow {
                        id: pairedRow
                        required property var modelData
                        Layout.fillWidth: true
                        headline: pairedRow.modelData.name || pairedRow.modelData.address
                        busy: BluetoothService.busyDeviceAddress === pairedRow.modelData.address
                        supportingText: pairedRow.busy ? "Working…" : pairedRow.modelData.connected ? "Connected" : "Paired"
                        leadingIcon: pairedRow.modelData.iconName || "bluetooth"
                        leadingIconColor: pairedRow.modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                        trailingSupportingText: pairedRow.modelData.battery >= 0 ? Math.round(pairedRow.modelData.battery * 100) + "%" : ""
                        onClicked: {
                            if (pairedRow.modelData.connected) root.bluetoothMenu(pairedRow.modelData.device)
                            else BluetoothService.connectDevice(pairedRow.modelData.device)
                        }
                        onOptionsRequested: root.bluetoothMenu(pairedRow.modelData.device)
                    }
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: BluetoothService.errorMessage !== ""
                    text: BluetoothService.errorMessage
                    textFormat: Text.PlainText
                    textStyle: "bodySmall"
                    colorRole: "error"
                    wrapMode: Text.WordWrap
                }
                MaterialButton {
                    Layout.fillWidth: true
                    visible: BluetoothService.pairingPending
                    text: "Cancel pairing"
                    variant: "text"
                    onClicked: BluetoothService.cancelPairing()
                }
                MaterialButton {
                    Layout.fillWidth: true
                    visible: BluetoothService.enabled
                    text: root.findingBluetooth ? "Back to saved devices" : "Pair new device…"
                    variant: "text"
                    onClicked: root.findingBluetooth = !root.findingBluetooth
                }
                Repeater {
                    model: ScriptModel { values: root.bluetoothDiscovery ? BluetoothService.discoveredDevices : []; objectProp: "address" }
                    delegate: ConnectionRow {
                        id: newDeviceRow
                        required property var modelData
                        Layout.fillWidth: true
                        headline: newDeviceRow.modelData.name || newDeviceRow.modelData.address
                        leadingIcon: newDeviceRow.modelData.iconName || "bluetooth"
                        supportingText: busy ? "Pairing…" : "Pair"
                        busy: BluetoothService.busyDeviceAddress === newDeviceRow.modelData.address
                        hasOptions: false
                        onClicked: BluetoothService.pairDevice(newDeviceRow.modelData.device)
                    }
                }
                MaterialText {
                    Layout.fillWidth: true
                    visible: root.findingBluetooth
                    text: BluetoothService.scanning ? "Searching for devices…" : "Search finished"
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                }
                MaterialButton {
                    Layout.fillWidth: true
                    visible: root.findingBluetooth
                    text: BluetoothService.scanning ? "Stop searching" : "Search again"
                    variant: "text"
                    onClicked: { if (BluetoothService.scanning) BluetoothService.stopScan(); else BluetoothService.startScan() }
                }
            }
            ConnectionHeader {
                Layout.fillWidth: true
                visible: VPNService.enabled
                headline: "VPN"
                leadingIcon: VPNService.icon
                supportingText: root.section === "vpn" ? "" : VPNService.busy ? "Working…" : VPNService.connected ? VPNService.activeVPN : "Not connected"
                expanded: root.section === "vpn"
                onClicked: root.toggleSection("vpn")
            }
            Repeater {
                model: ScriptModel { values: root.section === "vpn" && VPNService.enabled ? Array.from(VPNService.availableVPNs) : [] }
                delegate: ConnectionRow {
                    id: vpnRow
                    required property string modelData
                    Layout.fillWidth: true
                    headline: vpnRow.modelData
                    leadingIcon: "vpn_key"
                    supportingText: VPNService.busyVPN === vpnRow.modelData ? "Working…" : VPNService.activeVPN === vpnRow.modelData ? "Connected" : ""
                    busy: VPNService.busy
                    onClicked: {
                        if (VPNService.activeVPN === vpnRow.modelData) vpnRow.optionsRequested()
                        else VPNService.connect(vpnRow.modelData)
                    }
                    onOptionsRequested: {
                        root.targetVpn = vpnRow.modelData
                        root.showActions("vpn", vpnRow.modelData, [
                            {label: VPNService.activeVPN === vpnRow.modelData ? "Disconnect" : "Connect", action: "connect", enabled: !VPNService.busy},
                            {label: "Edit connections…", action: "editor", icon: "open_in_new"}
                        ])
                    }
                }
            }
            ConnectionRow {
                Layout.fillWidth: true
                visible: EthernetService.connected
                headline: "Ethernet"
                supportingText: "Connected"
                leadingIcon: "lan"
                onClicked: root.showActions("ethernet", "Ethernet", [{label: "Connection details", icon: "info", action: "details"}, {label: "Edit connections…", icon: "open_in_new", action: "editor"}])
                onOptionsRequested: clicked()
            }

        }
    }

    BluetoothPairingDialog {
        id: pairingDialog
        requestToken: BluetoothService.pairingToken
        requestKind: BluetoothService.pairingKind
        deviceName: BluetoothService.pairingName
        deviceAddress: BluetoothService.pairingAddress
        code: BluetoothService.pairingCode
        serviceUuid: BluetoothService.pairingUuid
        entered: BluetoothService.pairingEntered
        validationError: BluetoothService.pairingError
        onAnswered: (token, value) => BluetoothService.answerPairing(token, value)
        onRejected: token => BluetoothService.rejectPairing(token)
    }
    Dialog {
        id: actionDialog
        dialogWidth: root.width - Tokens.spacing.small * 2
        dialogHeight: menuColumn.implicitHeight + Tokens.spacing.small * 2
        onOpened: Qt.callLater(() => menu.focusFirst())
        ScrollableList {
            anchors.fill: parent
            contentPadding: Tokens.spacing.small
            ColumnLayout {
                id: menuColumn
                Layout.fillWidth: true
                MaterialText { Layout.fillWidth: true; text: root.menuTitle; textStyle: "titleSmall"; elide: Text.ElideRight }
                MaterialMenu {
                    id: menu
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    model: root.menuActions
                    onTriggered: index => root.runAction(root.menuActions[index])
                }
            }
        }
    }
    Dialog {
        id: passwordDialog
        dialogWidth: root.width - Tokens.spacing.small * 2
        dialogHeight: passwordColumn.implicitHeight + Tokens.spacing.medium * 2
        function submit() {
            if (!root.targetNetwork || passwordField.text.length === 0 || NetworkService.newConnectionBusy) return
            if (!NetworkService.connectToNewNetwork(root.targetNetwork, passwordField.text)) return
            passwordField.text = ""
            passwordDialog.close()
        }
        onVisibleChanged: if (!visible) { passwordField.text = ""; passwordField.password = true }
        ScrollableList {
            anchors.fill: parent
            contentPadding: Tokens.spacing.medium
            ColumnLayout {
                id: passwordColumn
                Layout.fillWidth: true
                MaterialText { Layout.fillWidth: true; text: root.targetNetwork ? "Connect to " + root.targetNetwork.name : "Network is no longer available"; textStyle: "titleSmall"; wrapMode: Text.WordWrap }
                MaterialText {
                    Layout.fillWidth: true
                    visible: NetworkService.errorMessage !== ""
                    text: NetworkService.errorMessage
                    textFormat: Text.PlainText
                    textStyle: "bodySmall"
                    colorRole: "error"
                    wrapMode: Text.WordWrap
                }
                MaterialTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    password: true
                    trailingIcon: password ? "visibility" : "visibility_off"
                    onTrailingClicked: password = !password
                    onAccepted: passwordDialog.submit()
                }
                MaterialButton { Layout.fillWidth: true; text: "Connect"; enabled: NetworkService.wifiReady && root.targetNetwork !== null && !root.targetNetwork.connected && !root.targetNetwork.stateChanging && passwordField.text.length > 0 && !NetworkService.newConnectionBusy; onClicked: passwordDialog.submit() }
                MaterialButton { Layout.fillWidth: true; text: "Cancel"; variant: "text"; onClicked: passwordDialog.close() }
            }
        }
    }
    Dialog {
        id: detailsDialog
        dialogWidth: root.width - Tokens.spacing.small * 2
        dialogHeight: detailsColumn.implicitHeight + Tokens.spacing.medium * 2
        ScrollableList {
            anchors.fill: parent
            contentPadding: Tokens.spacing.medium
            ColumnLayout {
                id: detailsColumn
                Layout.fillWidth: true
                Repeater {
                    model: root.detailLines
                    MaterialText { required property string modelData; Layout.fillWidth: true; text: modelData; textStyle: "bodyMedium"; wrapMode: Text.WrapAnywhere }
                }
                MaterialButton { Layout.fillWidth: true; text: "Back"; variant: "text"; onClicked: detailsDialog.close() }
            }
        }
    }
    Dialog {
        id: forgetDialog
        dialogWidth: root.width - Tokens.spacing.small * 2
        dialogHeight: forgetColumn.implicitHeight + Tokens.spacing.medium * 2
        ScrollableList {
            anchors.fill: parent
            contentPadding: Tokens.spacing.medium
            ColumnLayout {
                id: forgetColumn
                Layout.fillWidth: true
                MaterialText {
                    Layout.fillWidth: true
                    text: "Forget " + root.menuTitle + "?"
                    textStyle: "titleSmall"
                    wrapMode: Text.WordWrap
                }
                MaterialButton {
                    Layout.fillWidth: true
                    text: "Forget"
                    onClicked: {
                        if (root.menuKind === "wifi" && root.targetNetwork) NetworkService.forgetNetwork(root.targetNetwork)
                        else if (root.menuKind === "bluetooth" && root.targetDevice) BluetoothService.forgetDevice(root.targetDevice)
                        forgetDialog.close()
                    }
                }
                MaterialButton { Layout.fillWidth: true; text: "Cancel"; variant: "text"; onClicked: forgetDialog.close() }
            }
        }
    }
}
