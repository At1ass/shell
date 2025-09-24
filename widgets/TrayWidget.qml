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
    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: Config.colors.outline
    }
}