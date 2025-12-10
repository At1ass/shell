pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Основной список уведомлений (как в ii)
    property list<Notif> list: []
    // Список popup уведомлений (property var, не list<>!)
    property var popupList: list.filter((notif) => notif.popup)

    property bool silent: false
    property bool popupInhibited: silent

    // Component для создания уведомлений
    Component {
        id: notifComponent
        Notif {}
    }

    // Component для таймеров
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    // Определение типа уведомления (как в ii)
    component Notif: QtObject {
        id: wrapper
        required property int notificationId
        property Notification notification
        property list<var> actions: notification?.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property int urgency: notification?.urgency ?? NotificationUrgency.Normal

        property Timer timer

        // Lock/unlock механизм для безопасного удаления во время анимаций
        property var locks: new Set()

        function lock(item) {
            locks.add(item);
        }

        function unlock(item) {
            locks.delete(item);
            // Если popup=false и нет блокировок, можно безопасно удалить
            if (popup === false && locks.size === 0) {
                root.discardNotification(notificationId);
            }
        }

        onNotificationChanged: {
            if (notification === null) {
                root.discardNotification(notificationId);
            }
        }
    }

    // Определение таймера (как в ii)
    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        onTriggered: () => {
            root.timeoutNotification(notificationId);
            destroy()
        }
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": notification.id,
                "notification": notification,
                "time": Date.now(),
            });
            root.list = [...root.list, newNotifObject];

            // Popup (как в ii)
            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                if (notification.expireTimeout != 0) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": notification.expireTimeout < 0 ? 7000 : notification.expireTimeout,
                    });
                }
            }

            console.log("[NotificationService] New notification:", notification.summary, "popup:", newNotifObject.popup)
        }
    }

    function discardNotification(id) {
        console.log("[Notifications] Discarding notification with ID:", id);
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id === id);
        if (index !== -1) {
            root.list.splice(index, 1);
            triggerListChange()
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss()
        }
    }

    function discardAllNotifications() {
        root.list = []
        triggerListChange()
        notifServer.trackedNotifications.values.forEach((notif) => {
            notif.dismiss()
        })
    }

    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].timer.stop();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            notif.popup = false;
        });
    }

    function attemptInvokeAction(id, notifIdentifier) {
        console.log("[Notifications] Attempting to invoke action:", notifIdentifier, "for notification ID:", id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id === id);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((action) => action.identifier === notifIdentifier);
            action.invoke()
        } else {
            console.log("Notification not found in server:", id)
        }
        root.discardNotification(id);
    }

    function triggerListChange() {
        root.list = root.list.slice(0)
    }
}
