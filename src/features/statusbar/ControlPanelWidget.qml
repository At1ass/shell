import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: false
    hoverable: true

    property bool panelOpen: GlobalStates.controlPanelOpen

    implicitWidth: content.width + 12

    onClicked: function(mouse) {
        console.log("ControlPanelWidget clicked, current state:", GlobalStates.controlPanelOpen)
        if (mouse && mouse.button === Qt.LeftButton) {
            console.log("ControlPanel toggle clicked")
            GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }
    }

    Row {
        id: content
        spacing: Config.spacing.small

        // Иконка системной панели
        MaterialIcon {
            iconName: "settings"
            // iconStyle: "bold"
            fontSize: Config.typography.titleLarge.size
            iconColor: Config.colors.onSurface
            color: "transparent"
            enableRipple: false
        }

        // Индикатор состояния (опционально)
        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Config.colors.primary
            opacity: panelOpen ? 1.0 : 0.0
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }
}
