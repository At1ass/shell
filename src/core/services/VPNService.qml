pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root
    function init() {}
    readonly property bool enabled: AppConfig.vpnEnabled
    Loader {
        id: modelLoader
        active: AppConfig.ready && root.enabled
        source: active ? "connectivity/NativeVpnProfiles.qml" : ""
    }
    function value(name, fallback) { return modelLoader.item ? (modelLoader.item[name] ?? fallback) : fallback }
    function invoke(name, args) {
        const item = modelLoader.item
        return item && typeof item[name] === "function" ? item[name](...args) : false
    }
    readonly property bool ready: value("ready", false)
    readonly property var profiles: Array.from(value("profiles", []))
    readonly property list<string> availableVPNs: value("names", [])
    readonly property list<string> activeUuids: value("activeUuids", [])
    readonly property bool connected: activeUuids.length > 0
    readonly property string activeVPN: value("activeNames", "")
    readonly property string icon: connected ? "vpn_lock" : "vpn_key_off"
    readonly property string errorMessage: root._actionError || value("errorString", "")
        || (modelLoader.status === Loader.Error ? "VPN information is unavailable" : "")
    property string busyVPN: ""
    readonly property bool busy: busyVPN !== ""
    property string _actionError: ""
    property int _generation: 0
    property int _operationGeneration: 0
    property bool _disconnecting: false

    onEnabledChanged: { ++root._generation; root.clearError() }
    function clearError() { root._actionError = "" }
    // A generic action opens the choice; it never guesses a primary profile.
    function toggle() {
        if (!root.enabled) { ToastService.info("VPN tracking is off — set services.vpn.enabled in config.json"); return }
        GlobalStates.openConnections("vpn", null)
    }
    function refresh() { if (enabled) invoke("refresh", []) }
    function openSettings() { AppLaunchService.launchCommand(["nm-connection-editor"]) }
    function connect(uuid) { return root._run(uuid, false) }
    function disconnect(uuid) { return root._run(uuid, true) }
    function _run(uuid, down) {
        if (!root.enabled || !root.ready || root.busy || actionProc.running
                || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid)) return false
        const profile = root.invoke("profile", [uuid])
        if (!profile?.uuid || profile.busy || (down ? !profile.connected : profile.connected)) return false
        root.clearError()
        root.busyVPN = profile.uuid
        root._disconnecting = down
        root._operationGeneration = root._generation
        actionProc.command = ["nmcli", "--wait", String(AppConfig.networkAuthenticationTimeout + 30),
            "connection", down ? "down" : "up", "uuid", profile.uuid]
        actionProc.running = true
        return true
    }
    Process {
        id: actionProc
        objectName: "vpnOperation"
        onExited: exitCode => {
            root.busyVPN = ""
            root.refresh()
            if (!root.enabled || root._operationGeneration !== root._generation) return
            if (exitCode === 0) {
                if (!GlobalStates.connectionsOpen) ToastService.success(root._disconnecting ? "VPN disconnected" : "VPN connected")
            } else {
                root._actionError = exitCode === 3 ? "VPN operation timed out."
                    : exitCode === 10 ? "VPN connection is no longer available."
                    : root._disconnecting ? "Could not disconnect VPN."
                    : "VPN connection failed. Check credentials or edit the profile."
                if (!GlobalStates.connectionsOpen) ToastService.error(root._actionError)
            }
        }
    }
    Connections {
        target: GlobalStates
        function onConnectionsOpenChanged() { if (GlobalStates.connectionsOpen) root.clearError() }
    }
}
