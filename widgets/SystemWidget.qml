import QtQuick
import qs.components.base
import qs.config

BarElement {
    id: systemWidget

    // BarElement configuration
    clickable: true
    minWidth: 80

    onClicked: {
        console.log("System widget clicked")
    }

    // System indicators content
    Row {
        spacing: 4

        // Network indicator (placeholder)
        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Config.colors.secondary
            anchors.verticalCenter: parent.verticalCenter
        }

        // Battery indicator (placeholder)
        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Config.colors.tertiary
            anchors.verticalCenter: parent.verticalCenter
        }

        // Audio indicator (placeholder)
        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Config.colors.primary
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}