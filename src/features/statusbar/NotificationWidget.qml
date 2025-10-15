import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.core.config
import qs.src.core.services

// Notification widget для StatusBar
BarElement {
    id: root

    property var tooltipManager: null
    clickable: true
    hoverable: false
    minWidth: 64

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            GlobalStates.notificationSidebarOpen = !GlobalStates.notificationSidebarOpen
            mouse.accepted = true
            return
        }
        mouse.accepted = false
    }

    RowLayout {
        id: content
        // anchors.left: parent.left
        // anchors.verticalCenter: parent.verticalCenter
        // anchors.leftMargin: Config.spacing.small
        spacing: Config.spacing.small

        // Icon
        MaterialIcon {
            iconName: {
                if (NotificationService.dndEnabled) {
                    return "notifications_off"
                }
                if (NotificationService.unreadCount > 0) {
                    return "notifications_active"
                }
                return "notifications"
            }
            iconColor: {
                if (NotificationService.dndEnabled) {
                    return Config.colors.onSurfaceVariant
                }
                if (NotificationService.unreadCount > 0) {
                    return Config.colors.primary
                }
                return Config.colors.onSurface
            }
            fontSize: Config.typography.titleLarge.size
        }

        // Count badge (when > 0)
        Rectangle {
            id: smallBadge
            visible: NotificationService.unreadCount > 0 && NotificationService.unreadCount < 10
            width: countText.implicitWidth + 8
            height: 18
            radius: height / 2
            color: Config.colors.primary

            MaterialText {
                id: countText
                anchors.centerIn: parent
                text: NotificationService.unreadCount
                textStyle: "labelSmall"
                colorRole: "onPrimary"
            }
        }

        // "9+" badge when >= 10
        Rectangle {
            id: largeBadge
            visible: NotificationService.unreadCount >= 10
            width: 24
            height: 18
            radius: height / 2
            color: Config.colors.primary

            MaterialText {
                anchors.centerIn: parent
                text: "9+"
                textStyle: "labelSmall"
                colorRole: "onPrimary"
            }
        }
    }
}
