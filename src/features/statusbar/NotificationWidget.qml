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
    minWidth: 48

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            GlobalStates.notificationCenterOpen = !GlobalStates.notificationCenterOpen
        } else if (mouse.button === Qt.RightButton) {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        }
    }

    RowLayout {
        spacing: Config.spacing.extraSmall

        Item {
            width: 24
            height: 24

            MaterialIcon {
                anchors.centerIn: parent
                iconName: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
                fontSize: Config.typography.titleLarge.size
                iconColor: NotificationService.doNotDisturb ? Config.colors.tertiary :
                          (root.hovered ? Config.colors.primary : Config.colors.onSurface)
                backgroundColor: "transparent"
            }

            Badge {
                visible: NotificationService.historyList.count > 0
                text: NotificationService.historyList.count > 99
                      ? "99+"
                      : NotificationService.historyList.count.toString()
            }
        }
    }
}
