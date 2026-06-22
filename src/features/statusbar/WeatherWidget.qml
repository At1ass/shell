import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: true
    hoverable: true
    minWidth: 56

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showLocation: widgetSettings.showLocation ?? true
    property bool showIcon: widgetSettings.showIcon ?? true
    property bool showTemp: widgetSettings.showTemp ?? true


    clickHandler: function(mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        MaterialText {
            visible: root.showLocation
            text: Weather.location
            textStyle: "bodyMedium"
            colorRole: "onSurface"
        }

        MaterialIcon {
            visible: root.showIcon
            iconName: Weather.icon
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            visible: root.showTemp
            text: Math.round(Weather.tempC) + Weather.tempUnit
            textStyle: "bodyMedium"
            colorRole: "onSurface"
        }
    }
}
