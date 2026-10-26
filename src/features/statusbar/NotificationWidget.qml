import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.feedback

BarElement {
    id: root
    clickable: true
    hoverable: true
    minWidth: Tokens.size.control
    readonly property bool needsAttention: !NotificationService.doNotDisturb && NotificationService.unreadCount > 0

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showCount: widgetSettings.showCount ?? true

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            if (widgetConfig?.clickAction) {
                GlobalStates.handleClickAction(widgetConfig.clickAction)
            } else {
                GlobalStates.togglePanel("notificationCenter")
            }
            mouse.accepted = true
        } else if (mouse.button === Qt.RightButton) {
            NotificationService.toggleDoNotDisturb()
            mouse.accepted = true
        } else {
            mouse.accepted = false
        }
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        Item {
            implicitWidth: Tokens.iconSize.large
            implicitHeight: Tokens.iconSize.large

            MaterialIcon {
                anchors.centerIn: parent
                iconName: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
                fontSize: Tokens.typography.titleLarge.size
                iconColor: NotificationService.doNotDisturb ? Theme.tertiary : Theme.onSurface
            }

            // UNREAD, not history size. The badge used to count every stored
            // row, so it climbed to "99+" and stayed there regardless of
            // whether the user had looked — useless as an indicator.
            Badge {
                visible: root.showCount && NotificationService.unreadCount > 0
                text: NotificationService.unreadCount > 99
                      ? "99+"
                      : NotificationService.unreadCount.toString()
            }
        }
    }
}
