pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.src.core.services

Singleton {
    id: root

    readonly property list<QtObject> activeNotifications: notifications.filter(n => !n.closed)
    readonly property list<QtObject> popupNotifications: activeNotifications.filter(n => n.popup)

    property list<QtObject> notifications: []

    readonly property var notificationGroups: {
        const groups = new Map()

        for (const entry of activeNotifications) {
            const key = entry.groupKey
            let group = groups.get(key)

            if (!group) {
                group = {
                    key: key,
                    displayName: entry.displayName,
                    appIcon: entry.appIcon,
                    notifications: [],
                    latestTime: entry.time.getTime()
                }
                groups.set(key, group)
            }

            group.notifications.push(entry)
            group.latestTime = Math.max(group.latestTime, entry.time.getTime())

            if (!group.appIcon && entry.appIcon) {
                group.appIcon = entry.appIcon
            }
        }

        return Array.from(groups.values()).sort((a, b) => b.latestTime - a.latestTime)
    }

    readonly property var notificationsByApp: {
        const dict = {}
        notificationGroups.forEach(group => dict[group.key] = group)
        return dict
    }

    readonly property var appNames: notificationGroups.map(group => group.key)
    readonly property int unreadCount: activeNotifications.length

    property bool dndEnabled: false
    readonly property bool popupSuppressed: dndEnabled
            || GlobalStates.notificationSidebarOpen
            || GlobalStates.dashboardOpen
            || GlobalStates.launcherOpen
    property int maxPopupCount: 3

    readonly property string storagePath: {
        const stateDir = Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
        return stateDir + "/quickshell/notifications.json"
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function (notification) {
            if (!notification)
                return

            notification.tracked = true
            const key = String(notification.id)
            const existing = root.notifications.find(n => n.id === key && !n.closed)
            const showPopup = root.shouldShowPopup(notification)
            const timestamp = new Date()

            if (existing) {
                existing.time = timestamp
                existing.popup = showPopup
                existing.persistent = false
                existing.applyNotification(notification)
                existing.notification = notification
                if (showPopup)
                    existing.resetPopupTimer()
                root.enforcePopupLimit()
                saveTimer.restart()
                return
            }

            const entry = notificationEntryComponent.createObject(root, {
                notification: notification,
                popup: showPopup,
                time: timestamp
            })

            entry.initializeFromNotification(notification)

            root.notifications = [entry, ...root.notifications]
            root.enforcePopupLimit()
            saveTimer.restart()
        }
    }

    Component {
        id: notificationEntryComponent

        QtObject {
            id: entry

            default property list<QtObject> data

            property Notification notification: null
            property string id: ""
            property string summary: ""
            property string body: ""
            property string appName: ""
            property string displayName: ""
            property string groupKey: "other"
            property string appIcon: ""
            property string image: ""
            property int urgency: NotificationUrgency.Normal
            property bool hasActionIcons: false
            property bool resident: false
            property bool closed: false
            property bool popup: false
            property bool persistent: false
            property date time: new Date()
            property int expireTimeout: 0
            property var _connectedNotification: null
            readonly property bool canAutoClose: expireTimeout > 0
            property int remainingTimeout: 0
            property int currentTimerInterval: expireTimeout

            function handleClosed() {
                entry.close(true)
            }

            readonly property var actionsModel: _actionsModel
            property var _actionsModel: []

            readonly property Timer autoCloseTimer: Timer {
                interval: entry.canAutoClose ? entry.currentTimerInterval : 0
                repeat: false
                running: entry.popup && !entry.closed && entry.canAutoClose
                onTriggered: {
                    entry.popup = false
                    entry.remainingTimeout = 0
                    saveTimer.restart()
                }
            }

            readonly property string timeStr: {
                const diff = Date.now() - entry.time.getTime()
                const minutes = Math.floor(diff / 60000)

                if (minutes < 1) return "now"
                if (minutes < 60) return `${minutes}m`

                const hours = Math.floor(minutes / 60)
                if (hours < 24) return `${hours}h`

                const days = Math.floor(hours / 24)
                return `${days}d`
            }

            onPopupChanged: popup => {
                if (popup) {
                    resetPopupTimer()
                } else {
                    remainingTimeout = 0
                    autoCloseTimer.stop()
                }
            }

            onClosedChanged: closedNow => {
                if (closedNow)
                    autoCloseTimer.stop()
            }

            onExpireTimeoutChanged: resetPopupTimer()

            onNotificationChanged: notif => {
                if (notif) {
                    initializeFromNotification(notif)
                } else {
                    attachNotification(null)
                    _actionsModel = []
                }
            }

            function resetPopupTimer() {
                if (!canAutoClose || closed || !popup)
                    return
                remainingTimeout = expireTimeout
                currentTimerInterval = expireTimeout
                autoCloseTimer.stop()
                autoCloseTimer.start()
            }

            function pausePopupTimer() {
                if (canAutoClose) {
                    remainingTimeout = Math.max(0, autoCloseTimer.remainingTime)
                    autoCloseTimer.stop()
                }
            }

            function resumePopupTimer() {
                if (canAutoClose && popup && !closed) {
                    currentTimerInterval = remainingTimeout > 0 ? remainingTimeout : expireTimeout
                    remainingTimeout = 0
                    autoCloseTimer.start()
                }
            }

            function applyNotification(notif) {
                if (!notif)
                    return

                id = String(notif.id)
                summary = notif.summary ?? ""
                body = notif.body ?? ""
                appName = notif.appName ?? ""
                displayName = appName.length > 0 ? appName : (notif.desktopEntry ?? "Other")
                groupKey = chooseGroupKey(notif.desktopEntry, appName)
                appIcon = notif.appIcon ?? ""
                image = notif.image ?? ""
                urgency = notif.urgency ?? NotificationUrgency.Normal
                hasActionIcons = notif.hasActionIcons ?? false
                resident = notif.resident ?? false
                if (notif.expireTimeout === 0) {
                    expireTimeout = 0
                } else if (notif.expireTimeout > 0) {
                    expireTimeout = notif.expireTimeout
                } else {
                    expireTimeout = 7000
                }
                rebuildActions(notif)
            }

            function initializeFromNotification(notif) {
                applyNotification(notif)
                attachNotification(notif)
            }

            function initializeFromStored(data) {
                id = data.id ?? ""
                summary = data.summary ?? ""
                body = data.body ?? ""
                appName = data.appName ?? ""
                displayName = data.displayName ?? (appName.length > 0 ? appName : data.groupKey ?? "Other")
                groupKey = data.groupKey ?? chooseGroupKey("", appName)
                appIcon = data.appIcon ?? ""
                image = data.image ?? ""
                urgency = data.urgency ?? NotificationUrgency.Normal
                resident = data.resident ?? false
                expireTimeout = data.expireTimeout ?? 0
                hasActionIcons = data.hasActionIcons ?? false
                persistent = true
                rebuildActions()
            }

            function attachNotification(notif) {
                if (_connectedNotification) {
                    try {
                        _connectedNotification.closed.disconnect(handleClosed)
                    } catch (err) {
                        // ignore
                    }
                    _connectedNotification = null
                }

                if (notif) {
                    try {
                        notif.closed.connect(handleClosed)
                        _connectedNotification = notif
                    } catch (err) {
                        console.warn("Failed to connect notification closed signal", err)
                    }
                }
            }

            Component.onDestruction: {
                if (_connectedNotification) {
                    try {
                        _connectedNotification.closed.disconnect(handleClosed)
                    } catch (err) {}
                    _connectedNotification = null
                }
            }

            function rebuildActions(sourceNotif) {
                const src = sourceNotif !== undefined && sourceNotif !== null
                        ? sourceNotif
                        : notification
                if (!src || !src.actions || src.actions.length === 0) {
                    _actionsModel = []
                    return
                }

                const actions = []
                for (let i = 0; i < src.actions.length; ++i) {
                    const action = src.actions[i]
                    actions.push({
                        identifier: action.identifier,
                        text: action.text
                    })
                }
                _actionsModel = actions
            }

            function invokeAction(identifier) {
                if (!notification)
                    return

                for (let i = 0; i < notification.actions.length; ++i) {
                    const action = notification.actions[i]
                    if (action.identifier === identifier) {
                        action.invoke()
                        return
                    }
                }
            }

            function close(fromNotification) {
                if (closed)
                    return

                closed = true
                popup = false
                autoCloseTimer.stop()

                if (!fromNotification && notification) {
                    notification.dismiss()
                }

                root.removeEntry(entry)
            }

            function chooseGroupKey(desktopEntry, name) {
                if (desktopEntry && desktopEntry.length > 0)
                    return desktopEntry
                if (name && name.length > 0)
                    return name
                return "Other"
            }

            function toJson() {
                return {
                    id: id,
                    summary: summary,
                    body: body,
                    appName: appName,
                    displayName: displayName,
                    groupKey: groupKey,
                    appIcon: appIcon,
                    image: image,
                    urgency: urgency,
                    resident: resident,
                    hasActionIcons: hasActionIcons,
                    expireTimeout: expireTimeout,
                    time: time.getTime()
                }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: save()
    }

    function save() {
        const data = activeNotifications
            .map(entry => entry.toJson())

        fileView.setText(JSON.stringify(data, null, 2))
    }

    function load() {
        fileView.reload()
    }

    function shouldShowPopup(notification) {
        if (popupSuppressed || !notification)
            return false
        return true
    }

    function enforcePopupLimit() {
        if (popupNotifications.length <= maxPopupCount)
            return

        const extra = popupNotifications.slice(maxPopupCount)
        extra.forEach(entry => entry.popup = false)
    }

    function suppressPopups() {
        notifications.forEach(entry => entry.popup = false)
    }

    function removeEntry(entry) {
        const remaining = notifications.filter(n => n !== entry)
        if (remaining.length === notifications.length)
            return

        notifications = remaining
        entry.destroy()
        saveTimer.restart()
    }

    function clearAll() {
        notifications.slice().forEach(entry => entry.close(false))
    }

    function clearApp(groupKey) {
        notifications.slice().forEach(entry => {
            if (entry.groupKey === groupKey) {
                entry.close(false)
            }
        })
    }

    FileView {
        id: fileView
        path: root.storagePath

        onLoaded: {
            try {
                const data = JSON.parse(text())
                const restored = data.map(item => {
                    const obj = notificationEntryComponent.createObject(root, {
                        popup: false,
                        time: new Date(item.time ?? Date.now())
                    })
                    obj.initializeFromStored(item)
                    return obj
                })

                root.notifications = restored.concat(root.notifications)
                console.log("Loaded", restored.length, "notifications from storage")
            } catch (error) {
                console.error("Failed to load notifications:", error)
                root.notifications = root.notifications.filter(entry => !entry.persistent)
            }
        }

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound) {
                setText("[]")
            } else {
                console.error("Failed to load notifications:", error)
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function clearAll(): void {
            root.clearAll()
        }

        function toggleDnd(): void {
            root.dndEnabled = !root.dndEnabled
        }

        function enableDnd(): void {
            root.dndEnabled = true
        }

        function disableDnd(): void {
            root.dndEnabled = false
        }
    }

    onDndEnabledChanged: {
        if (dndEnabled)
            suppressPopups()
        else
            enforcePopupLimit()
    }

    onMaxPopupCountChanged: enforcePopupLimit()

    Connections {
        target: GlobalStates

        function onNotificationSidebarOpenChanged(open) {
            if (open)
                suppressPopups()
            else
                enforcePopupLimit()
        }

        function onDashboardOpenChanged(open) {
            if (open)
                suppressPopups()
            else
                enforcePopupLimit()
        }

        function onLauncherOpenChanged(open) {
            if (open)
                suppressPopups()
            else
                enforcePopupLimit()
        }
    }

    Component.onCompleted: load()
}
