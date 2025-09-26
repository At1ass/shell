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
        spacing: Config.spacing.extraSmall

        // Network indicator
        MaterialIndicator {
            size: "extraSmall"
            colorRole: "secondary"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Battery indicator
        MaterialIndicator {
            size: "extraSmall"
            colorRole: "tertiary"
            anchors.verticalCenter: parent.verticalCenter
        }

        // Audio indicator
        MaterialIndicator {
            size: "extraSmall"
            colorRole: "primary"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
