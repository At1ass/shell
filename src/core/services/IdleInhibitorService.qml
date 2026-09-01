pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.core.config

// Caffeine: holds the session awake by keeping a Wayland idle inhibitor alive.
//
// The flag is USER state, so it lives in state.json rather than in memory. It
// used to be a plain `GlobalStates.inhibit` bool, which reset to false on every
// shell restart AND on every QML hot-reload — the shell would silently stop
// inhibiting while the toggle still read as off, so nothing looked wrong.
//
// Derive-from-state / write-to-state, the shape NotificationDND documents: a
// read-write property with an onChanged persister loops through stateData and
// severs its own binding on the first imperative write.
Singleton {
    id: root

    readonly property bool inhibit: AppConfig.stateData?.idleInhibitor?.enabled ?? false

    function setInhibit(on) {
        if (on !== root.inhibit)
            AppConfig.updateState("idleInhibitor", { "enabled": on })
    }

    function toggleInhibit() {
        root.setInhibit(!root.inhibit)
    }

    IdleInhibitor {
        enabled: root.inhibit

        // The protocol wants a surface to attach the inhibitor to; it is never
        // drawn and never takes input.
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            anchors {
                right: true
                bottom: true
            }
            mask: Region {
                item: null
            }
        }
    }
}
