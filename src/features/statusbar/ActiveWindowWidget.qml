import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.feedback
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

    property bool shown: ActiveWindowService.windowTitle !== ""
    hoverable: true
    clickable: !!widgetConfig?.clickAction
    clip: true

    preferredWidth: Math.max(minimumWidth, Math.min(title.implicitWidth, root.maxWidth)
        + (showIcon ? appIcon.implicitWidth + Tokens.spacing.extraSmall : 0) + Tokens.spacing.medium)
    minimumWidth: Math.max(Tokens.size.control, (showIcon ? appIcon.implicitWidth + Tokens.spacing.extraSmall : 0) + Tokens.spacing.medium)
    compactWidth: minimumWidth

    clickHandler: function(mouse) {
        if ((mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    nonVisualChildren: [TooltipItem {
        tooltip: root.tooltipManager
        owner: root
        show: root.hovered && root.barRevealed
        text: ActiveWindowService.windowTitle
    }]
    RowLayout {
        id: content
        width: Math.max(0, root.width - Tokens.spacing.medium)
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            id: appIcon
            visible: root.showIcon
            iconName: IconCategoryResolver.getAppCategoryIcon(ActiveWindowService.windowClass)
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            id: title
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: ActiveWindowService.windowTitle
            textStyle: "bodyMedium"
            colorRole: "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: root.maxWidth
        }
    }
}
