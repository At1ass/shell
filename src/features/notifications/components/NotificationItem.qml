import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications as Notifications
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

// Одно уведомление (Material Design 3)
MaterialCard {
    id: root

    property var notification: null
    property bool isPopup: false
    property bool showAppName: false
    property real swipeOffset: 0
    property bool dismissing: false
    readonly property bool hasActions: notification && notification.actionsModel && notification.actionsModel.length > 0
    readonly property bool hasImage: notification && notification.image && notification.image.length > 0
    readonly property bool isCritical: notification && notification.urgency === Notifications.NotificationUrgency.Critical
    readonly property string appIconPath: notification && notification.appIcon
                                          ? Quickshell.iconPath(notification.appIcon, "")
                                          : ""

    // MD3 colors based on urgency
    readonly property color bgColor: {
        if (isCritical)
            return Config.colors.errorContainer
        if (notification && notification.urgency === Notifications.NotificationUrgency.Low)
            return Config.colors.surfaceContainerLow
        return Config.colors.surfaceContainer
    }

    readonly property color textColor: {
        if (isCritical)
            return Config.colors.onErrorContainer
        return Config.colors.onSurface
    }

    implicitHeight: contentColumn.implicitHeight + 16
    color: bgColor
    radius: Config.shape.large
    outlined: false

    layer.enabled: isPopup
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.35
        shadowVerticalOffset: 6
        shadowHorizontalOffset: 0
        shadowColor: Qt.rgba(0, 0, 0, 0.32)
    }

    // Slide-in animation для popup
    opacity: isPopup ? 0 : 1
    transform: Translate {
        x: root.swipeOffset
    }

    Component.onCompleted: {
        if (isPopup) {
            Qt.callLater(() => popupEnter.start())
        }
    }

    SequentialAnimation {
        id: popupEnter
        running: false
        ScriptAction { script: root.swipeOffset = root.width }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "swipeOffset"
                to: 0
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1]
            }
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1]
            }
        }
    }

    Behavior on swipeOffset {
        enabled: !dismissing
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        onEntered: if (isPopup && notification) notification.pausePopupTimer()
        onExited: if (isPopup && !pressed && notification) notification.resumePopupTimer()

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton && notification) {
                notification.close()
            }
        }

        onPressed: if (isPopup && notification) notification.pausePopupTimer()
        onReleased: if (isPopup && notification && !containsMouse) notification.resumePopupTimer()
    }

    DragHandler {
        id: swipeHandler
        enabled: root.isPopup && !!root.notification
        target: null
        dragThreshold: 8
        onActiveChanged: active => {
            if (notification)
                active ? notification.pausePopupTimer() : notification.resumePopupTimer()

            if (active || !root.notification)
                return

            if (Math.abs(root.swipeOffset) > root.width * 0.35) {
                root.dismissing = true
                dismissAnimation.to = root.swipeOffset >= 0 ? root.width : -root.width
                dismissAnimation.start()
            } else {
                root.swipeOffset = 0
            }
        }
        onTranslationChanged: root.swipeOffset = translation.x
        grabPermissions: PointerHandler.CanTakeOverFromAnything
    }

    NumberAnimation {
        id: dismissAnimation
        running: false
        target: root
        property: "swipeOffset"
        duration: 160
        easing.type: Easing.InCubic
        onFinished: {
            if (root.notification) {
                const notif = root.notification
                notif.popup = false
                notif.close()
            }
            root.dismissing = false
            root.swipeOffset = 0
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Icon
            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: isCritical ? Config.colors.error : Config.colors.secondaryContainer
                }

                Loader {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    active: appIconPath !== ""
                    sourceComponent: Component {
                        Image {
                            anchors.fill: parent
                            source: root.appIconPath
                            sourceSize.width: 64
                            sourceSize.height: 64
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            cache: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: parent.width
                                    height: parent.height
                                    radius: width / 2
                                }
                            }
                        }
                    }
                }

                Loader {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    active: appIconPath === ""
                    sourceComponent: Component {
                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: root.isCritical ? "error" : "notifications"
                            iconColor: root.isCritical
                                       ? Config.colors.onError
                                       : Config.colors.onSecondaryContainer
                            fontSize: 24
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                // App name (optional)
                MaterialText {
                    visible: showAppName
                    text: notification && notification.appName ? notification.appName : ""
                    colorRole: "onSurfaceVariant"
                    textStyle: "labelSmall"
                }

                // Summary
                MaterialText {
                    Layout.fillWidth: true
                    text: notification && notification.summary ? notification.summary : ""
                    color: root.textColor
                    textStyle: "titleMedium"
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: showAppName ? 2 : 3
                    elide: Text.ElideRight
                }
            }

            // Time
            MaterialText {
                text: notification && notification.timeStr ? notification.timeStr : ""
                colorRole: "onSurfaceVariant"
                textStyle: "labelSmall"
            }

            // Close button
            IconButton {
                iconName: "close"
                iconSize: 18
                onClicked: if (notification) notification.close()
            }
        }

        // Body
        MaterialText {
            Layout.fillWidth: true
            text: notification && notification.body ? notification.body : ""
            colorRole: "onSurfaceVariant"
            textStyle: "bodyMedium"
            wrapMode: Text.Wrap
            textFormat: Text.MarkdownText
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: notification && notification.body && notification.body.length > 0
        }

        Loader {
            active: root.hasImage
            Layout.fillWidth: true
            sourceComponent: Rectangle {
                radius: Config.shape.medium
                color: Config.colors.surfaceContainerHigh
                implicitHeight: 160

                Image {
                    anchors.fill: parent
                    source: notification.image
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                }
            }
        }

        // Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.hasActions
            Layout.alignment: Qt.AlignRight

            Item { Layout.fillWidth: true } // spacer

            Repeater {
                model: root.hasActions ? notification.actionsModel : []

                MaterialButton {
                    variant: "text"
                    text: modelData.text
                    onClicked: {
                        if (!notification)
                            return
                        notification.invokeAction(modelData.identifier)
                    }
                }
            }
        }
    }
}
