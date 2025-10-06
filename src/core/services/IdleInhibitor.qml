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

    property alias inhibit: idleInhibitor.enabled
    inhibit: GlobalStates.inhibit

    function toggleInhibit() {
        GlobalStates.inhibit = !GlobalStates.inhibit
    }

    IdleInhibitor {
        id: idleInhibitor
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
