pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

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
                field.text = ""
                field.inputItem.forceActiveFocus()
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

        // Escape lives on the field, not on the window: a PanelWindow is not an
        // Item, so `Keys` cannot attach to it ("Could not attach Keys property
        // ... is not an Item") and the handler silently never ran.
        Surface {
            id: card

            anchors.centerIn: parent
            elevation: 3
            radius: Tokens.shape.extraLarge
            implicitWidth: 420
            implicitHeight: layout.implicitHeight + Tokens.spacing.large * 2

            // Swallow clicks so they do not reach the scrim behind.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: layout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.spacing.large
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        iconName: "admin_panel_settings"
                        fontSize: Tokens.iconSize.large
                        colorRole: "primary"
                    }

                    MaterialText {
                        Layout.fillWidth: true
                        text: "Authentication required"
                        textStyle: "titleMedium"
                        colorRole: "onSurface"
                    }
                }

                MaterialText {
                    Layout.fillWidth: true
                    text: PolkitService.message
                    textStyle: "bodyMedium"
                    colorRole: "onSurfaceVariant"
                    wrapMode: Text.Wrap
                    visible: text.length > 0
                }

                // Who to authenticate AS. polkit offers a choice for
                // `auth_admin` actions: the list is the administrators allowed
                // to approve this action (by default the members of `wheel`),
                // and the password entered below is theirs, not necessarily
                // yours. Hidden when there is only one — which is the case for
                // `auth_self` actions and for single-admin machines — because a
                // picker with one entry is noise.
                //
                // `displayName`, not `toString()`: Identity is a QObject, so
                // toString() renders "Identity(0x...)". It exposes `id`,
                // `string` (the account name), `displayName` (the full name,
                // falling back to the account name) and `isGroup`.
                MaterialComboBox {
                    Layout.fillWidth: true
                    visible: PolkitService.identities.length > 1
                    model: PolkitService.identities.map(i => i.displayName || i.string)
                    onCurrentIndexChanged: {
                        const id = PolkitService.identities[currentIndex]
                        if (id)
                            PolkitService.selectIdentity(id)
                    }
                }

                // Visible for the whole request, not only while
                // `responseRequired` is set: polkit drops that flag between
                // prompts, and gating on it made the field vanish and reappear
                // mid-conversation while the submit button stayed enabled with
                // nothing to submit.
                MaterialTextField {
                    id: field

                    Layout.fillWidth: true
                    placeholderText: PolkitService.prompt
                    password: !PolkitService.responseVisible
                    onAccepted: scope._submit()
                    Keys.onEscapePressed: PolkitService.cancel()

                }

                MaterialText {
                    Layout.fillWidth: true
                    text: PolkitService.failureMessage
                    textStyle: "bodySmall"
                    colorRole: "error"
                    wrapMode: Text.Wrap
                    visible: text.length > 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    MaterialButton {
                        text: "Cancel"
                        variant: "text"
                        onClicked: PolkitService.cancel()
                    }

                    MaterialButton {
                        text: "Authenticate"
                        variant: "filled"
                        enabled: PolkitService.responseRequired && !scope.submitting
                                 && field.text.length > 0
                        onClicked: scope._submit()
                    }
                }
            }
        }

        // A fresh request must not inherit the previous one's typed text, and
        // the field has to take focus without the user clicking into a prompt
        // that appeared over what they were doing.
        onVisibleChanged: {
            if (visible) {
                scope.submitting = false
                field.text = ""
                field.inputItem.forceActiveFocus()
            }
        }

        // Each retry after a wrong password clears the field, says so, and
        // takes focus back.
        Connections {
            target: PolkitService.flow
            function onAuthenticationFailed() {
                scope.submitting = false
                field.text = ""
                field.inputItem.forceActiveFocus()
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
        if (field.text.length === 0)
            return
        scope.submitting = true
        const response = field.text
        // Cleared BEFORE the call returns: the response is in PAM's hands from
        // here, and there is no reason for the password to keep living in a
        // visible text field.
        field.text = ""
        PolkitService.submit(response)
    }
}
