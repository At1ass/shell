pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

// One history row.
//
// Takes typed properties rather than a bag object: the centre's delegate used to
// rebuild a 12-field literal on every change of any single field, which
// invalidated every binding in here at once.
MaterialCard {
    id: root

    // ── Row data ──────────────────────────────────────────────────
    property int rowIndex: -1
    property string entryId: ""      // history row key
    property int notifId: 0          // live Notification.id, 0 = no longer live
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property real timestamp: 0
    property int repeatCount: 1
    property bool unread: false
    // Keyboard cursor position, driven by the list's currentIndex.
    property bool selected: false
    // False while grouping is on — the section header already names the app.
    property bool showAppName: true

    property bool expanded: true

    readonly property bool isCritical: root.urgency === NotificationUrgency.Critical
    // Actions are only rendered while expanded, and building them walks a
    // nested sub-model, so keep that off the path when the row is collapsed.
    readonly property var actions: (root.expanded && root.rowIndex >= 0)
                                   ? NotificationHistory.actionsAt(root.rowIndex) : []
    readonly property var visibleActions: root.actions.filter(
        a => a.identifier !== "default" && (a.text || "").trim().length > 0)
    readonly property bool actionsUsable: root.notifId > 0 && NotificationService.isLive(root.notifId)

    implicitHeight: contentLayout.implicitHeight + (Tokens.spacing.medium * 2)
    color: root.isCritical ? Theme.errorContainer : Theme.surfaceContainerHigh
    radius: Tokens.shape.medium

    // Swipe-to-dismiss. Coords kept in scene (window) frame via mapToItem
    // — local MouseArea x is unstable when root.x mutates during drag.
    property real _dragStartX: 0
    property real _dragInitialRootX: 0
    property bool _swiping: false

    ParallelAnimation {
        id: snapBack
        MotionAnimation {
            target: root; property: "x"; to: 0
            duration: Tokens.motion.duration.short4
            curve: "standard"
        }
        NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: Tokens.motion.duration.short3 }
    }

    SequentialAnimation {
        id: swipeDismiss
        property real targetX: root.width
        MotionAnimation {
            target: root; property: "x"; to: swipeDismiss.targetX
            duration: Tokens.motion.duration.short3
            curve: "emphasizedAccelerate"
        }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: Tokens.motion.duration.short1 }
        ScriptAction {
            script: {
                root._swiping = false
                NotificationService.removeFromHistory(root.entryId)
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
        onReleased: root._finishSwipe()
        onCanceled: root._finishSwipe()
    }

    function _finishSwipe() {
        if (root._swiping && Math.abs(root.x) > 50) {
            swipeDismiss.targetX = root.x > 0 ? root.width : -root.width
            swipeDismiss.start()
        } else if (root._swiping || root.x !== 0) {
            root._swiping = false
            snapBack.start()
        }
    }

    // Tonal elevation tint. This was a hand-rolled Rectangle holding
    // `Tokens.stateLayer.hoverOpacity` — a STATE-layer token standing in for an
    // elevation tint, which is why a resting card looked permanently hovered.
    SurfaceTint {
        level: 1
        radius: root.radius
    }

    // Hover and keyboard-focus feedback, from the design system rather than a
    // second hand-rolled overlay. The focus ring is what makes j/k navigation
    // visible at all.
    StateLayer {
        layerColor: root.isCritical ? Theme.onErrorContainer : Theme.onSurface
        hovered: historyMouseArea.containsMouse
        focused: root.selected
        showFocusRing: root.selected
        ringColor: root.isCritical ? Theme.error : Theme.primary
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        // Provenance line — only when the app is not already named by the
        // group header above.
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: root.showAppName && root.appName !== ""

            Image {
                visible: root.appIcon !== ""
                source: root.appIcon ? Quickshell.iconPath(root.appIcon) : ""
                Layout.preferredWidth: Tokens.iconSize.medium
                Layout.preferredHeight: Tokens.iconSize.medium
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Tokens.iconSize.medium
                sourceSize.height: Tokens.iconSize.medium
                smooth: true
            }

            MaterialText {
                text: root.appName
                textStyle: "labelMedium"
                colorRole: root.isCritical ? "onErrorContainer" : "onSurfaceVariant"
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }

        // Headline row. The summary lives HERE rather than on its own line:
        // with the app name hidden inside a group, the old metadata row had
        // nothing on its left and rendered as a wide empty gap above every card.
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // Unread marker — a plain dot, so "new since you last looked" reads
            // at a glance without competing with the urgency colouring.
            MaterialIndicator {
                visible: root.unread
                size: "small"
                shape: "circle"
                colorRole: root.isCritical ? "onErrorContainer" : "primary"
            }

            MaterialText {
                text: root.summary
                textStyle: "titleSmall"
                colorRole: root.isCritical ? "onErrorContainer" : "onSurface"
                visible: text.length > 0
                elide: Text.ElideRight
                maximumLineCount: root.expanded ? 2 : 1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            // Repeat count carried over from merged duplicates.
            Badge {
                inline: true
                visible: root.repeatCount > 1
                text: "×" + root.repeatCount
                badgeColor: Theme.secondaryContainer
                textColor: Theme.onSecondaryContainer
            }

            MaterialText {
                text: root.formatRelativeTime(root.timestamp, DateTime.clock.date)
                textStyle: "labelSmall"
                colorRole: root.isCritical ? "onErrorContainer" : "onSurfaceVariant"
                visible: root.timestamp > 0
                Layout.alignment: Qt.AlignTop
            }

            IconButton {
                iconName: root.expanded ? "expand_less" : "expand_more"
                iconSize: Tokens.iconSize.small
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                visible: root.body !== "" || root.image !== ""
                onClicked: root.expanded = !root.expanded
                Layout.alignment: Qt.AlignTop
            }

            IconButton {
                iconName: "close"
                iconSize: Tokens.iconSize.small
                containerSize: 28
                touchTargetSize: 32
                variant: "standard"
                onClicked: NotificationService.removeFromHistory(root.entryId)
                Layout.alignment: Qt.AlignTop
            }
        }

        MaterialText {
            text: root.body
            textStyle: "bodyMedium"
            textFormat: Text.StyledText
            colorRole: root.isCritical ? "onErrorContainer" : "onSurfaceVariant"
            visible: root.expanded && text.length > 0
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        // Notification image. Volatile image://qsimage/ handles are dropped:
        // they cannot outlive their notification, and old history files may
        // still carry them.
        Item {
            readonly property string imageSource:
                root.image.startsWith("image://qsimage/") ? "" : root.image
            visible: root.expanded && imageSource !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(historyNotifImage.implicitHeight, 180) : 0
            clip: true

            Image {
                id: historyNotifImage
                anchors.fill: parent
                source: parent.imageSource
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
            visible: root.expanded && root.visibleActions.length > 0

            Repeater {
                model: root.visibleActions

                MaterialButton {
                    required property var modelData
                    text: modelData.text
                    variant: "tonal"
                    // Actions address the LIVE notification, so they key on
                    // notifId, not the history row id. A row whose notification
                    // is gone disables them instead of failing silently.
                    enabled: root.actionsUsable
                    onClicked: NotificationService.invokeActionFromHistory(
                                   root.notifId, modelData.identifier)
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
        const diffSec = Math.floor((now - timestamp) / 1000)
        const diffMin = Math.floor(diffSec / 60)
        const diffHour = Math.floor(diffMin / 60)
        const diffDay = Math.floor(diffHour / 24)

        if (diffSec < 60) return "now"
        if (diffMin < 60) return diffMin + "m"
        if (diffHour < 24) return diffHour + "h"
        if (diffDay < 7) return diffDay + "d"

        return Qt.formatDateTime(new Date(timestamp), "MMM d")
    }
}
