pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.feedback

// The prompt polkit shows when something asks for privileges.
//
// Not part of the GlobalStates panel machine on purpose: an authentication
// request arrives when the SYSTEM decides, not when the user opens something,
// so it must be able to appear over whatever is already on screen and must not
// be closed by `closeAll`.
Scope {
    id: scope


    PanelWindow {
        id: win

        // Latched when a request starts. The window outlives a single request
        // (see shell.qml), so resolving at construction would pin every future
        // prompt to whichever output was focused at shell start. The fallback
        // covers the first evaluation, before the latch has anything in it.
        property ShellScreen targetScreen: null

        screen: win.targetScreen ?? GlobalStates.focusedScreen()
        visible: PolkitService.active

        Connections {
            target: PolkitService
            function onActiveChanged() {
                if (PolkitService.active)
                    win.targetScreen = GlobalStates.focusedScreen()
            }

            // A fresh prompt within the same request (a retry, or the password
            // stage arriving after another factor) releases the submit guard
            // and hands focus back.
            function onResponseRequiredChanged() {
                if (!PolkitService.responseRequired)
                    return
                scope.submitting = false
                prompt.password = ""
                prompt.focusInput()
            }
        }

        WlrLayershell.namespace: "quickshell:polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        // The prompt is dismissed only DELIBERATELY — the Cancel button or
        // Escape. Clicking away does not cancel, and neither does losing the
        // focus grab.
        //
        // Not a style choice. polkit authentication runs the full `system-auth`
        // stack (/usr/lib/pam.d/polkit-1 includes it), so `pam_faillock` counts
        // a cancelled conversation as a FAILED ATTEMPT exactly like a wrong
        // password. With the stock deny=3 that means three stray clicks lock
        // the account for ten minutes — measured on this machine, entries
        // logged against `polkit-1` for cancels alone. A privilege prompt has
        // to be hard to dismiss by accident.
        HyprlandFocusGrab {
            windows: [win]
            active: win.visible
        }

        Scrim {
            shown: win.visible

            // Swallows clicks so they reach neither the desktop nor a cancel.
            MouseArea {
                anchors.fill: parent
            }
        }

        PolkitPrompt {
            id: prompt
            anchors.centerIn: parent
            width: Math.max(1, Math.min(implicitWidth, win.width - Tokens.spacing.small * 2))
            height: Math.max(1, Math.min(implicitHeight, win.height - Tokens.spacing.small * 2))
            message: PolkitService.message
            identities: PolkitService.identities.map(i => i.displayName || i.string)
            identityIndex: {
                const selected = PolkitService.flow?.selectedIdentity?.string ?? ""
                return Math.max(0, PolkitService.identities.findIndex(identity => identity.string === selected))
            }
            prompt: PolkitService.prompt
            responseVisible: PolkitService.responseVisible
            responseRequired: PolkitService.responseRequired
            failureMessage: PolkitService.failureMessage
            submitting: scope.submitting
            onSubmitted: scope._submit()
            onCancelled: PolkitService.cancel()
            onIdentitySelected: index => {
                const identity = PolkitService.identities[index]
                if (identity) PolkitService.selectIdentity(identity)
            }
        }

        // A fresh request must not inherit the previous one's typed text, and
        // the field has to take focus without the user clicking into a prompt
        // that appeared over what they were doing.
        onVisibleChanged: {
            scope.submitting = false
            prompt.password = ""
            if (visible) prompt.focusInput()
        }

        // Each retry after a wrong password clears the field, says so, and
        // takes focus back.
        Connections {
            target: PolkitService.flow
            function onAuthenticationFailed() {
                scope.submitting = false
                prompt.password = ""
                prompt.focusInput()
            }
        }
    }

    // `submitting` is cleared by the next prompt (onResponseRequired below) or
    // by the request ending. Without it a second Return re-sends while the
    // first is still in PAM, which reads as two failed attempts.
    property bool submitting: false

    function _submit() {
        // polkit is not asking for anything right now — on a stack with
        // pam_fprintd the flow starts this way, waiting for a finger, and a
        // submit here is silently discarded. DankMaterialShell defers the typed
        // password until the prompt arrives (`awaitingFprintForPassword`);
        // this shell has no fingerprint stage, so it simply refuses.
        if (!PolkitService.responseRequired || scope.submitting)
            return
        if (prompt.password.length === 0)
            return
        scope.submitting = true
        const response = prompt.password
        // Cleared BEFORE the call returns: the response is in PAM's hands from
        // here, and there is no reason for the password to keep living in a
        // visible text field.
        prompt.password = ""
        PolkitService.submit(response)
    }
}
