import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Notifications as Notifications
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import "." as NotifComponents

MaterialCard {
    id: root

    required property string groupKey
    property string appName: groupKey
    property var notifications: []
    property bool expanded: false
    property real swipeOffset: 0

    readonly property var items: Array.isArray(notifications) ? notifications : []
    readonly property int notificationCount: items.length
    readonly property var latestNotification: notificationCount > 0 ? items[0] : null
    readonly property bool hasCritical: items.some(n => n.urgency === Notifications.NotificationUrgency.Critical)

    implicitHeight: content.implicitHeight + 16
    color: Config.colors.surfaceContainer
    radius: Config.shape.large
    outlined: false
    transform: Translate { x: root.swipeOffset }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.hasCritical ? Config.colors.error : Config.colors.secondaryContainer
        opacity: Math.min(1, Math.abs(root.swipeOffset) / Math.max(1, root.width)) * 0.18
        z: -0.5
        visible: opacity > 0
        antialiasing: true
        border.width: 0
    }

    Behavior on swipeOffset {
        NumberAnimation {
            duration: Config.motion.duration.medium1
            easing.type: Config.motion.easing.emphasizedDecelerate
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                color: root.hasCritical ?
                       Config.colors.errorContainer :
                       Config.colors.secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: (latestNotification && latestNotification.appIcon) ? latestNotification.appIcon : "notifications"
                    iconColor: root.hasCritical ?
                               Config.colors.onErrorContainer :
                               Config.colors.onSecondaryContainer
                    fontSize: 28
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialText {
                    text: root.appName
                    colorRole: "onSurface"
                    textStyle: "titleMedium"
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.expanded && root.notificationCount > 0
                    spacing: 8

                    MaterialText {
                        Layout.fillWidth: true
                        text: latestNotification ? latestNotification.summary : ""
                        colorRole: "onSurfaceVariant"
                        textStyle: "bodySmall"
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    MaterialText {
                        text: latestNotification ? latestNotification.timeStr : ""
                        colorRole: "onSurfaceVariant"
                        textStyle: "labelSmall"
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: badgeText.implicitWidth + 20
                radius: 14
                color: root.hasCritical ?
                       Config.colors.error :
                       Config.colors.secondaryContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    MaterialText {
                        id: badgeText
                        text: root.notificationCount
                        color: root.hasCritical ?
                               Config.colors.onError :
                               Config.colors.onSecondaryContainer
                        textStyle: "labelLarge"
                        font.weight: Font.Medium
                    }

                    MaterialIcon {
                        iconName: root.expanded ? "expand_less" : "expand_more"
                        iconColor: root.hasCritical ?
                                   Config.colors.onError :
                                   Config.colors.onSecondaryContainer
                        fontSize: 20
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }

            IconButton {
                iconName: "delete_sweep"
                iconSize: 20
                enabled: root.notificationCount > 0
                onClicked: NotificationService.clearApp(root.groupKey)
            }
        }

        Loader {
            active: !root.expanded && root.notificationCount > 0
            Layout.fillWidth: true
            sourceComponent: NotifComponents.NotificationItem {
                Layout.fillWidth: true
                width: parent ? parent.width : undefined
                notification: root.latestNotification
                isPopup: false
                showAppName: false
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: root.expanded

            Repeater {
                model: root.items

                NotifComponents.NotificationItem {
                    Layout.fillWidth: true
                    notification: modelData
                    isPopup: false
                    showAppName: false
                }
            }
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.emphasizedDecelerate
        }
    }

    DragHandler {
        id: groupDragHandler
        enabled: !root.expanded
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: root.swipeOffset = translation.x
        onActiveChanged: active => {
            if (!active) {
                if (Math.abs(root.swipeOffset) > root.width * 0.35) {
                    NotificationService.clearApp(root.groupKey)
                }
                root.swipeOffset = 0
            }
        }
        grabPermissions: PointerHandler.CanTakeOverFromAnything
    }
}
