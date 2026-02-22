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

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showCount: widgetSettings.showCount ?? true

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            if (widgetConfig?.clickAction) {
                GlobalStates.handleClickAction(widgetConfig.clickAction)
            } else {
                GlobalStates.notificationCenterOpen = !GlobalStates.notificationCenterOpen
            }
            mouse.accepted = true
        } else if (mouse.button === Qt.RightButton) {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb
            mouse.accepted = true
        } else {
            mouse.accepted = false
        }
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        Item {
            width: 24
            height: 24

            MaterialIcon {
                anchors.centerIn: parent
                iconName: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
                fontSize: Tokens.typography.titleLarge.size
                iconColor: NotificationService.doNotDisturb ? Theme.tertiary :
                          (root.hovered ? Theme.primary : Theme.onSurface)
                backgroundColor: "transparent"
            }

            Badge {
                visible: root.showCount && NotificationService.historyList.count > 0
                text: NotificationService.historyList.count > 99
                      ? "99+"
                      : NotificationService.historyList.count.toString()
            }
        }
    }
}
