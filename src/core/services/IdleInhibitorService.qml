// import qs
import qs.src.core.services
import QtQuick
import Quickshell
import Quickshell.Wayland
pragma Singleton

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    // Readonly property with a binding only - no alias conflict
    readonly property bool inhibit: GlobalStates.inhibit

    function toggleInhibit() {
        GlobalStates.inhibit = !GlobalStates.inhibit
    }

    IdleInhibitor {
        id: idleInhibitor
        // Bind enabled directly to GlobalStates
        enabled: GlobalStates.inhibit
        window: PanelWindow { // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }

}
