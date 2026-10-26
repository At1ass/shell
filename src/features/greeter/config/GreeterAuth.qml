import QtQuick
import Quickshell.Services.Greetd

// One owner per greeter, with explicit continuation of additional PAM prompts.
QtObject {
    id: root
    property bool active: false
    property bool inProgress: false
    property bool responseRequired: false
    property bool echoResponse: false
    readonly property bool busy: inProgress && !responseRequired
    property string prompt: "Password"
    property string statusMessage: ""
    property string errorMessage: ""
    property string _pendingPassword: ""
    property list<string> _sessionArgv: []
    signal clearCredentials()
    signal focusRequested()

    onActiveChanged: if (!active) cancel()
    function reset() {
        inProgress = false
        responseRequired = false
        echoResponse = false
        prompt = "Password"
        _pendingPassword = ""
        _sessionArgv = []
        statusMessage = ""
        clearCredentials()
    }
    function cancel() {
        const owned = inProgress
        reset()
        if (owned && Greetd.available && Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
        focusRequested()
    }
    function submit(username, password, sessionArgv) {
        if (!active || busy) return
        if (responseRequired) {
            responseRequired = false
            errorMessage = ""
            clearCredentials()
            statusMessage = "Authenticating…"
            Greetd.respond(password)
            return
        }
        errorMessage = ""
        if (!Greetd.available) { errorMessage = "Login service unavailable"; return }
        const command = typeof sessionArgv === "string" ? [] : Array.from(sessionArgv ?? [])
        if (!username.trim() || !password || command.length === 0 || !command[0] || command.some(arg => typeof arg !== "string" || arg.includes("\0"))) { errorMessage = "Choose a user and session"; return }
        if (Greetd.state !== GreetdState.Inactive) { errorMessage = "Login service is busy"; return }
        inProgress = true
        _sessionArgv = command
        _pendingPassword = password
        clearCredentials()
        statusMessage = "Authenticating…"
        Greetd.createSession(username.trim())
    }
    readonly property Connections transport: Connections {
        target: Greetd
        enabled: root.active
        function onAuthMessage(message, error, required, echo) {
            if (!root.inProgress) return
            if (error) { root.errorMessage = message || "Authentication message"; return }
            root.statusMessage = message || "Authenticating…"
            if (!required) return
            if (root._pendingPassword !== "" && !echo) {
                const password = root._pendingPassword
                root._pendingPassword = ""
                Greetd.respond(password)
            } else {
                root._pendingPassword = ""
                root.prompt = message || "Response"
                root.echoResponse = echo
                root.responseRequired = true
                root.focusRequested()
            }
        }
        function onReadyToLaunch() {
            if (!root.inProgress || root._sessionArgv.length === 0) return
            root._pendingPassword = ""
            root.responseRequired = false
            root.clearCredentials()
            root.statusMessage = "Starting session…"
            Greetd.launch(root._sessionArgv, [], true)
        }
        function onAuthFailure(message) {
            if (!root.inProgress) return
            root.reset()
            root.errorMessage = message || "Authentication failed"
            root.focusRequested()
        }
        function onError(message) {
            if (!root.inProgress) return
            root.cancel()
            root.errorMessage = message || "Login service error"
        }
    }
    Component.onDestruction: { _pendingPassword = "" }
}
