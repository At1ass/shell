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
    minWidth: 64

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showIcon: widgetSettings.showIcon ?? true

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        if (mouse.button === Qt.RightButton) {
            NetworkService.openSettings()
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: NetworkService.icon
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
            color: "transparent"
        }

        MaterialText {
            text: {
                if (!NetworkService.wifiEnabled)
                    return "Wi-Fi Off";
                if (!NetworkService.currentNetwork)
                    return "No Network";
                return NetworkService.currentNetwork;
            }
            textStyle: "bodyMedium"
            colorRole: "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
