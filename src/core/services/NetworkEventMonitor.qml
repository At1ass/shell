pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One long-lived `nmcli monitor` drives every NetworkManager-backed
// service that has no native Quickshell API (ethernet, VPN). Replaces
// their periodic polling (~34k spawned processes/day when idle) with
// event-driven refreshes. shell.qml calls init() once at startup.
Singleton {
    id: root

    // Side-effect singletons instantiate on first reference; init() is that
    // reference, called from shell.qml. Deliberately empty.
    function init() {}

    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: data => refreshDebounce.restart()
        }

        // NetworkManager restart kills the monitor; bring it back and
        // resync state after a short delay.
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: {
            if (!monitorProc.running) {
                monitorProc.running = true
                refreshDebounce.restart()
            }
        }
    }

    // NM emits bursts (device + connection + connectivity lines per event);
    // coalesce them into a single refresh sweep.
    Timer {
        id: refreshDebounce
        interval: 300
        onTriggered: {
            EthernetService.refresh()
            VPNService.refresh()
        }
    }

    Component.onCompleted: {
        EthernetService.refresh()
        VPNService.refresh()
    }
}
