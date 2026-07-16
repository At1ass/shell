pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.core.config

Singleton {
    id: root

    property bool screenshotOverlayActive: false
    property string _grimGeometry: ""
    property bool _useSwappy: false
    property string screenshotTargetMonitor: ""

    // Geometry is passed as a positional argv ($1) into the shell script so
    // it cannot break out of quoting — the script string itself is a literal.
    Process {
        id: screenshotRegionProc
        command: ["sh", "-c",
                  'sleep 0.2 && grim -g "$1" - | wl-copy',
                  "sh", root._grimGeometry]
        onExited: (exitCode) => {
            if (exitCode === 0) ToastService.success("Screenshot copied to clipboard")
            else ToastService.error("Screenshot failed (grim exited " + exitCode + ")")
        }
    }

    Process {
        id: screenshotSwappyProc
        command: ["sh", "-c",
                  'sleep 0.2 && grim -g "$1" - | swappy -f -',
                  "sh", root._grimGeometry]
        // No exit handler — swappy manages its own save/cancel feedback;
        // closing the window is a normal action and should not show an error.
    }

    function takeScreenshot() {
        root.screenshotTargetMonitor = Hyprland.focusedMonitor?.name ?? ""
        GlobalStates.closePanel("dashboard")
        root._useSwappy = false
        root.screenshotOverlayActive = true
    }

    function takeScreenshotSwappy() {
        root.screenshotTargetMonitor = Hyprland.focusedMonitor?.name ?? ""
        GlobalStates.closePanel("dashboard")
        root._useSwappy = true
        root.screenshotOverlayActive = true
    }

    function captureRegion(geometry) {
        root._grimGeometry = geometry
        root.screenshotOverlayActive = false
        if (root._useSwappy) {
            root._useSwappy = false
            screenshotSwappyProc.running = true
        } else {
            screenshotRegionProc.running = true
        }
    }

}
