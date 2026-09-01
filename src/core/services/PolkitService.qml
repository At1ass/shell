pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// Polkit authentication agent.
//
// Without one, every graphical privilege request fails silently: the caller
// waits for an agent that never answers, so the action simply does not happen
// and nothing says why.
//
// THE AGENT MUST NOT EXIST WHEN `modules.polkit` IS OFF. Registering the role
// and then declining to prompt is worse than not registering: polkit hands the
// request to the registered agent and stops looking, so a disabled module would
// break authentication for the whole session instead of leaving it to another
// agent. The gate is therefore the singleton's own instantiation — QML creates
// a singleton on first reference, and shell.qml's loader reads
// `moduleEnabled("polkit")` BEFORE it touches anything here, so with the module
// off nothing in this file is ever constructed.
Singleton {
    id: root

    PolkitAgent {
        id: agent
    }

    // Whether an authentication request is on screen right now.
    readonly property bool active: agent.isActive

    // Whether the agent claimed the role. False if another agent registered
    // first — polkit allows one per session.
    readonly property bool registered: agent.isRegistered

    // The live request, or null. Read ONCE here and used through `root.flow`
    // below: Quickshell does not expose AuthFlow declaratively, so qmllint
    // cannot resolve the type and warns at every `root.flow` it sees. One
    // untyped hop keeps that to a single unavoidable site.
    // qmllint disable unresolved-type
    readonly property var flow: agent.flow
    // qmllint enable unresolved-type

    readonly property string actionId: root.flow?.actionId ?? ""
    readonly property string iconName: root.flow?.iconName ?? ""
    readonly property bool responseRequired: root.flow?.isResponseRequired ?? false
    readonly property bool responseVisible: root.flow?.responseVisible ?? false
    // Administrators allowed to approve the pending action (for `auth_admin`
    // rules; a single entry for `auth_self`). The flow pre-selects the first,
    // so submitting without choosing is valid.
    readonly property var identities: root.flow?.identities ?? []

    // polkit messages arrive with a trailing full stop and prompts with a
    // trailing colon; both read badly next to a heading and a text field.
    readonly property string message: {
        const m = root.flow?.message ?? ""
        return m.endsWith(".") ? m.slice(0, -1) : m
    }

    readonly property string prompt: {
        const p = (root.flow?.inputPrompt ?? "").trim()
        const cleaned = p.endsWith(":") ? p.slice(0, -1) : p
        if (cleaned)
            return cleaned
        return root.responseVisible ? "Response" : "Password"
    }

    // Supplementary text is the same field for both, told apart by a flag: a
    // wrong password arrives as an error, "authenticate to continue" as info.
    readonly property string error: root.flow?.supplementaryIsError
        ? (root.flow?.supplementaryMessage ?? "") : ""
    readonly property string info: root.flow?.supplementaryIsError
        ? "" : (root.flow?.supplementaryMessage ?? "")

    // Why the last attempt was rejected. Kept HERE rather than in the dialog:
    // request state belongs to the service, and polkit's own
    // `supplementaryMessage` stays empty on a wrong password (measured — it is
    // "" for the whole retry window), so without this the user saw the field
    // silently empty itself and nothing else. caelestia and end4 both park the
    // equivalent flag on their service for the same reason.
    property string failureMessage: ""

    // Set while a session restart WE asked for is in flight; see selectIdentity.
    property bool _switchingIdentity: false

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            // Switching identity is indistinguishable from a rejected password
            // at this signal. Quickshell's setSelectedIdentity cancels the live
            // session and starts a new one (flow.cpp), and only a cancel of the
            // whole REQUEST sets the flow's isCancelled flag — a session
            // cancelled for a restart falls into the failure branch and emits
            // this. Reported as "authentication failed" while merely picking a
            // different administrator, which is what the user saw.
            if (root._switchingIdentity) {
                root._switchingIdentity = false
                return
            }
            root.failureMessage = root.error || "Authentication failed"
        }

        // The replacement session is up; nothing is in flight any more. Belt and
        // braces, so a switch that somehow produced no failure cannot leave the
        // flag set and swallow the NEXT genuine one.
        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired)
                root._switchingIdentity = false
        }
    }

    Connections {
        target: agent
        function onAuthenticationRequestStarted() {
            root.failureMessage = ""
        }
    }

    function submit(response) {
        if (root.flow)
            root.flow.submit(response ?? "")
    }

    function cancel() {
        if (root.flow)
            root.flow.cancelAuthenticationRequest()
    }

    // Picking a different administrator restarts the PAM conversation as that
    // user. Two consequences worth knowing: the message below is suppressed for
    // the restart, and the cancelled session COSTS A LOGIN ATTEMPT — pam_faillock
    // counts it exactly like a wrong password (measured). The equality guard is
    // load-bearing: setSelectedIdentity returns early for an unchanged identity,
    // so setting the flag then would leave it armed to swallow a real failure.
    function selectIdentity(identity) {
        if (!root.flow || !identity)
            return
        if (root.flow.selectedIdentity === identity)
            return
        root._switchingIdentity = true
        root.flow.selectedIdentity = identity
    }

    // Also the only way to see, from outside, whether this agent won the role:
    // polkit allows one agent per session and the loser is told nothing beyond
    // a line in the log.
    IpcHandler {
        target: "polkit"

        function registered(): bool {
            return root.registered
        }

        function active(): bool {
            return root.active
        }

        function actionId(): string {
            return root.actionId
        }

        function prompt(): string {
            return root.prompt
        }

        function error(): string {
            return root.error
        }

        // Whole flow in one call. Diagnosing an authentication problem means
        // watching several properties change together, and polling them one IPC
        // call at a time races the flow's own transitions.
        function state(): string {
            return JSON.stringify({
                registered: root.registered,
                active: root.active,
                actionId: root.actionId,
                prompt: root.prompt,
                responseRequired: root.responseRequired,
                responseVisible: root.responseVisible,
                failed: root.flow?.failed ?? false,
                completed: root.flow?.isCompleted ?? false,
                successful: root.flow?.isSuccessful ?? false,
                cancelled: root.flow?.isCancelled ?? false,
                supplementary: root.flow?.supplementaryMessage ?? "",
                supplementaryIsError: root.flow?.supplementaryIsError ?? false,
                failureMessage: root.failureMessage,
                identities: root.identities.map(i => i.displayName || i.string)
            }, null, 2)
        }

        function cancel(): void {
            root.cancel()
        }
    }
}
