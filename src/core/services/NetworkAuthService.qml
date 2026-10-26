pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.core.config

// Credentials remain in the native agent. This facade only routes prompts and
// holds public metadata; it never persists answers or copies system secrets.
Singleton {
    id: root
    function init() {}
    IpcHandler {
        target: "networkauth"
        function registered(): bool { return root.registered }
        function busy(): bool { return root.busy }
        function cancel(): void { root.cancel() }
    }
    Loader {
        id: agentLoader
        active: AppConfig.ready && AppConfig.moduleEnabled("connections") && AppConfig.networkAgentEnabled
        source: active ? "connectivity/NativeNetworkAgent.qml" : ""
    }
    readonly property QtObject agent: agentLoader.item
    function value(name, fallback) { return agent ? (agent[name] ?? fallback) : fallback }
    function invoke(name, args) { return agent && typeof agent[name] === "function" ? agent[name](...args) : false }
    readonly property bool registered: value("registered", false)
    readonly property bool busy: value("busy", false)
    readonly property string requestToken: value("requestToken", "")
    readonly property string connectionName: value("connectionName", "")
    readonly property string message: value("message", "")
    readonly property string validationError: value("validationError", "")
    readonly property string section: value("section", "wifi")
    readonly property bool requestNew: value("requestNew", false)
    readonly property var fields: value("fields", [])
    readonly property string error: value("errorString", "")
    property bool _openedForAuth: false

    function submit(token, answers) { return invoke("submit", [token, answers]) }
    function reject(token) { return invoke("reject", [token]) }
    function cancel() { invoke("cancel", []) }
    onRequestTokenChanged: Qt.callLater(root.routePrompt)
    function routePrompt() {
        if (!requestToken || GlobalStates.lockscreenActive) return
        if (!GlobalStates.connectionsOpen) {
            root._openedForAuth = true
            GlobalStates.openConnections(root.section, null)
        } else GlobalStates.connectionsSection = root.section
    }
    onBusyChanged: if (!busy) Qt.callLater(() => {
        if (root.busy || !root._openedForAuth) return
        root._openedForAuth = false
        if (GlobalStates.connectionsOpen) GlobalStates.closePanel("connections")
    })
    onErrorChanged: if (error) ToastService.error(error)
    Connections {
        target: GlobalStates
        function onConnectionsOpenChanged() {
            if (!GlobalStates.connectionsOpen) {
                root._openedForAuth = false
                if (root.requestToken) root.cancel()
            }
        }
        function onConnectionsSectionChanged() {
            const token = root.requestToken
            if (!token) return
            Qt.callLater(() => {
                if (root.requestToken === token && GlobalStates.connectionsSection !== root.section) root.cancel()
            })
        }
    }
    Connections {
        target: SessionMonitor
        function onResumed() { root.cancel() }
    }
}
