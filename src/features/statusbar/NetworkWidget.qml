import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: true
    hoverable: true
    minWidth: Tokens.size.control
    preferredWidth: Math.max(minWidth, (showIcon ? networkIcon.implicitWidth : 0)
        + (showLabel ? Math.min(networkLabel.implicitWidth, Tokens.size.fieldWidth) : 0)
        + (showIcon && showLabel ? Tokens.spacing.extraSmall : 0) + Tokens.spacing.medium)
    minimumWidth: preferredWidth
    compactWidth: Math.max(minWidth, (showIcon ? networkIcon.implicitWidth : 0) + Tokens.spacing.medium)

    property var tooltipManager: null
    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showLabel: widgetSettings.showLabel ?? false
    property bool showIcon: widgetSettings.showIcon ?? true

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            const action = root.widgetConfig?.clickAction ?? "connections-wifi"
            if (action === "connections" || action === "connections-wifi" || action === "dashboard-network")
                GlobalStates.toggleConnections(action === "connections" ? "" : "wifi", root.actionAnchor)
            else if (action === "connections-bluetooth") GlobalStates.toggleConnections("bluetooth", root.actionAnchor)
            else GlobalStates.handleClickAction(action)
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

    nonVisualChildren: [
        TooltipItem {
            tooltip: root.tooltipManager
            owner: root
            show: root.hovered && root.barRevealed && !GlobalStates.connectionsOpen
            text: NetworkService.connectionLabel
        }
    ]

    RowLayout {
        width: Math.max(0, root.width - Tokens.spacing.medium)
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            id: networkIcon
            visible: root.showIcon
            iconName: NetworkService.connectionIcon
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            id: networkLabel
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: root.showLabel && (!root.compactPresentation || !root.showIcon)
            text: NetworkService.connectionLabel
            textStyle: "bodyMedium"
            colorRole: "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
