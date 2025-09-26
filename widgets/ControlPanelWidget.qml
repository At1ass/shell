import QtQuick
import QtQuick.Layouts
import qs.components.base
import qs.config
import qs.services

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
        MaterialText {
            text: "⚙"  // Или можно использовать другую иконку
            font.pixelSize: 22
            color: panelOpen ? Config.colors.primary : Config.colors.surfaceText
            opacity: panelOpen ? 1.0 : 0.7
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
