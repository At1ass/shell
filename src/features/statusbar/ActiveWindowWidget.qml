import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null

    property int maxWidth: widgetSettings.maxWidth ?? 300
    property bool showIcon: widgetSettings.showIcon ?? true

    visible: ActiveWindowService.windowTitle !== ""
    hoverable: true
    clickable: true
    clip: true

    implicitWidth: content.implicitWidth + Tokens.spacing.small * 2

    clickHandler: function(mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        id: content
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: IconCategoryResolver.getAppCategoryIcon(ActiveWindowService.windowClass)
            fontSize: Tokens.typography.titleLarge.size
            iconColor: root.hovered ? Theme.primary : Theme.onSurface
            color: "transparent"
        }

        MaterialText {
            text: ActiveWindowService.windowTitle
            textStyle: "bodyMedium"
            colorRole: root.hovered ? "primary" : "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: root.maxWidth
        }
    }
}
