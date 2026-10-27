pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.ui.feedback
import qs.src.core.services
import qs.src.ui.base

Scope {
    id: powerMenuScope

    readonly property var _actionDefs: [
        { icon: "lock",                label: "Lock",     action: "lock",     key: "L" },
        { icon: "dark_mode",           label: "Suspend",  action: "suspend",  key: "S" },
        { icon: "restart_alt",         label: "Reboot",   action: "reboot",   key: "R" },
        { icon: "power_settings_new",  label: "Shutdown", action: "shutdown", key: "D" },
        { icon: "logout",              label: "Logout",   action: "logout",   key: "O" }
    ]

    // powerMenu.actions from config selects and ORDERS the buttons —
    // config-first: the schema key is the interface, not decoration.
    readonly property var actions: {
        const out = []
        for (const name of AppConfig.powerMenuActions) {
            const def = _actionDefs.find(a => a.action === name)
            if (def) out.push(def)
        }
        return out.length > 0 ? out : _actionDefs
    }

    PanelWindow {
        id: menuWindow
        visible: GlobalStates.powerMenuOpen

        // The output to map onto, resolved by GlobalStates.openPanel once per
        // open and before the open flag flips -- so this window is still
        // invisible when it moves, and a RETAINED panel still lands on the
        // monitor the user is looking at. Resolving in Component.onCompleted
        // was only correct while every open rebuilt the window.
        screen: GlobalStates.activePanelScreen ?? null

        WlrLayershell.namespace: "quickshell:powermenu"
        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: focusGrab
            windows: [menuWindow]
            active: GlobalStates.powerMenuOpen

            onCleared: {
                GlobalStates.closePanel("powermenu")
            }
        }

        // Scrim
        Scrim {
            shown: GlobalStates.powerMenuOpen
            duration: Tokens.motion.duration.medium2

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.closePanel("powermenu")
            }
        }

        PowerMenuContent {
            id: menuContent
            anchors.centerIn: parent
            width: Math.max(0, Math.min(implicitWidth, menuWindow.width - Tokens.spacing.large * 2))
            height: Math.max(0, Math.min(implicitHeight, menuWindow.height - Tokens.spacing.large * 2))
            actions: powerMenuScope.actions
            confirmActions: AppConfig.powerMenuConfirmActions
            focus: true
            onActionRequested: action => GlobalStates.executePowerAction(action)
            onCloseRequested: GlobalStates.closePanel("powermenu")
            property bool ready: false
            Component.onCompleted: { ready = true; if (menuWindow.visible) reset() }
            opacity: ready && menuWindow.visible ? 1 : 0
            scale: ready && menuWindow.visible ? 1 : 0.9
            Behavior on opacity { MotionAnimation { duration: Tokens.motion.duration.medium4; curve: "emphasizedDecelerate" } }
            Behavior on scale { MotionAnimation { duration: Tokens.motion.duration.medium4; curve: "emphasizedDecelerate" } }
        }
        onVisibleChanged: {
            if (!menuContent) return
            if (visible) menuContent.reset()
            else menuContent.cancelConfirmation()
        }
    }
}
