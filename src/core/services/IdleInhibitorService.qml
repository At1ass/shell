pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

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

    readonly property TimedMode _mode: TimedMode { section: "idleInhibitor" }
    readonly property bool inhibit: _mode.enabled
    readonly property bool temporary: _mode.temporary
    readonly property real expiresAt: temporary ? _mode.expiresAt : 0
    readonly property string statusText: _mode.statusText
    function init() { _mode.refresh() }
    function setInhibit(on) { _mode.setEnabled(on) }
    function setForMinutes(minutes) { return _mode.start(minutes) }
    function toggleInhibit() { setInhibit(!inhibit) }

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
