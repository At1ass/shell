import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

MaterialCard {
    id: root
    property var notificationObject: null
    readonly property bool hasNotification: notificationObject !== null && notificationObject !== undefined
    property bool expanded: true
    implicitHeight: contentLayout.implicitHeight + (Tokens.spacing.medium * 2)

    color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
           ? Theme.errorContainer
           : Theme.surfaceContainerHigh
    radius: Tokens.shape.medium

    // Swipe-to-dismiss. Coords kept in scene (window) frame via mapToItem
    // — local MouseArea x is unstable when root.x mutates during drag.
    property real _dragStartX: 0
    property real _dragInitialRootX: 0
    property bool _swiping: false

    ParallelAnimation {
        id: snapBack
        NumberAnimation { target: root; property: "x"; to: 0; duration: Tokens.motion.duration.short4; easing.type: Tokens.motion.easing.standard }
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.motion.duration.short3 }
    }

    SequentialAnimation {
        id: swipeDismiss
        property real targetX: root.width
        NumberAnimation { target: root; property: "x"; to: swipeDismiss.targetX; duration: Tokens.motion.duration.short3; easing.type: Tokens.motion.easing.emphasizedAccelerate }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Tokens.motion.duration.short1 }
        ScriptAction {
            script: {
                root._swiping = false
                if (root.hasNotification)
                    NotificationService.removeFromHistory(notificationObject.notificationId)
            }
        }
    }

    MouseArea {
        id: historyMouseArea
        anchors.fill: parent
        hoverEnabled: true

        onPressed: (mouse) => {
            const scene = historyMouseArea.mapToItem(null, mouse.x, mouse.y)
            root._dragStartX = scene.x
            root._dragInitialRootX = root.x
            root._swiping = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return
            const scene = historyMouseArea.mapToItem(null, mouse.x, mouse.y)
            const dx = scene.x - root._dragStartX
            if (Math.abs(dx) > 10) root._swiping = true
            if (root._swiping) {
                root.x = root._dragInitialRootX + dx
                root.opacity = 1.0 - (Math.abs(root.x) / root.width) * 0.5
            }
        }
        onReleased: (mouse) => {
            root._finishSwipe()
        }
        onCanceled: {
            root._finishSwipe()
        }
    }

    function _finishSwipe() {
        if (_swiping && Math.abs(x) > 50) {
            swipeDismiss.targetX = x > 0 ? width : -width
            swipeDismiss.start()
        } else if (_swiping || x !== 0) {
            _swiping = false
            snapBack.start()
        }
    }

    // Hover state layer
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
               ? Theme.onErrorContainer : Theme.onSurface
        opacity: historyMouseArea.containsMouse ? Tokens.stateLayer.hoverOpacity : 0

        Behavior on opacity {
            NumberAnimation { duration: Tokens.motion.duration.short3 }
        }
    }

    // Surface tint
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.primary
        opacity: Tokens.stateLayer.hoverOpacity
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Image {
                visible: root.hasNotification && notificationObject.appIcon !== ""
                source: root.hasNotification && notificationObject.appIcon
                        ? Quickshell.iconPath(notificationObject.appIcon)
                        : ""
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 24
                sourceSize.height: 24
                smooth: true
            }

            MaterialText {
                text: root.hasNotification ? (notificationObject.appName || "") : ""
                textStyle: "labelMedium"
                colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? "onErrorContainer"
                           : "onSurfaceVariant"
                visible: text.length > 0
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            MaterialText {
                text: root.hasNotification ? root.formatRelativeTime(notificationObject.timestamp, DateTime.clock.date) : ""
                textStyle: "labelSmall"
                colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                           ? "onErrorContainer"
                           : "onSurfaceVariant"
                visible: root.hasNotification && notificationObject.timestamp !== undefined
            }

            IconButton {
                iconName: root.expanded ? "expand_less" : "expand_more"
                iconSize: Tokens.iconSize.small
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                visible: root.hasNotification && (!!notificationObject.body || !!notificationObject.image)
                onClicked: root.expanded = !root.expanded
            }

            IconButton {
                iconName: "close"
                iconSize: Tokens.iconSize.small
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                onClicked: {
                    if (root.hasNotification) {
                        NotificationService.removeFromHistory(notificationObject.notificationId)
                    }
                }
            }
        }

        MaterialText {
            text: root.hasNotification ? (notificationObject.summary || "") : ""
            textStyle: "titleSmall"
            colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                       ? "onErrorContainer"
                       : "onSurface"
            visible: text.length > 0
            elide: Text.ElideRight
            maximumLineCount: root.expanded ? 2 : 1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        MaterialText {
            text: root.hasNotification ? (notificationObject.body || "") : ""
            textStyle: "bodyMedium"
            textFormat: Text.StyledText
            colorRole: root.hasNotification && notificationObject.urgency === NotificationUrgency.Critical
                       ? "onErrorContainer"
                       : "onSurfaceVariant"
            visible: root.expanded && text.length > 0
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        // Notification image
        Rectangle {
            visible: root.expanded && root.hasNotification && (notificationObject.image || "") !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(historyNotifImage.implicitHeight, 180) : 0
            radius: Tokens.shape.small
            clip: true
            color: "transparent"

            Image {
                id: historyNotifImage
                anchors.fill: parent
                source: root.hasNotification ? (notificationObject.image || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: parent.width
            }
        }

        // Action buttons — horizontal flow. "default" and empty-label
        // actions are filtered (per freedesktop spec — default is body-click).
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            readonly property var _visibleActions: root.hasNotification
                ? (notificationObject.actions || []).filter(
                    a => a.identifier !== "default" && (a.text || "").trim().length > 0)
                : []

            visible: root.expanded && _visibleActions.length > 0

            Repeater {
                model: parent._visibleActions

                MaterialButton {
                    required property var modelData
                    text: modelData.text
                    variant: "tonal"
                    onClicked: {
                        if (root.hasNotification) {
                            NotificationService.attemptInvokeAction(
                                notificationObject.notificationId,
                                modelData.identifier
                            )
                        }
                    }
                }
            }
        }
    }

    // Relative time formatting. `nowDate` (DateTime.clock.date) is the
    // reactive dependency: it ticks each minute, so "now"/"5m" refresh
    // while the center stays open instead of freezing at open time.
    function formatRelativeTime(timestamp, nowDate) {
        if (!timestamp) return ""
        const now = nowDate ? nowDate.getTime() : Date.now()
        const diffMs = now - timestamp
        const diffSec = Math.floor(diffMs / 1000)
        const diffMin = Math.floor(diffSec / 60)
        const diffHour = Math.floor(diffMin / 60)
        const diffDay = Math.floor(diffHour / 24)

        if (diffSec < 60) return "now"
        if (diffMin < 60) return diffMin + "m"
        if (diffHour < 24) return diffHour + "h"
        if (diffDay < 7) return diffDay + "d"

        const date = new Date(timestamp)
        return Qt.formatDateTime(date, "MMM d")
    }
}
