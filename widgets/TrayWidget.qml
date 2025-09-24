import QtQuick
import qs.components.base
import qs.config

BarElement {
    id: trayWidget

    // BarElement configuration
    clickable: true
    minWidth: 40

    onClicked: {
        console.log("System tray clicked")
    }

    // Placeholder tray icon
    MaterialIndicator {
        size: "small"
        colorRole: "outline"
    }
}