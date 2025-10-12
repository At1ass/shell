import QtQuick
import QtQuick.Controls
import qs.src.core.config

// Material Design 3 Slider (2024 spec)
Slider {
    id: control

    stepSize: 0.01
    // from: orientation === Qt.Horizontal ? 0.0 : 1.0
    // to: orientation === Qt.Horizontal ? 1.0 : 0.0
    from: 0.0
    to: 1.0

    implicitWidth: orientation === Qt.Horizontal ? 200 : 48
    implicitHeight: orientation === Qt.Horizontal ? 48 : 200

    property real trackHeight: 16
    property real thumbWidth: 4
    property real thumbHeight: 44
    property real thumbTrackGap: 6
    property real trackCornerSize: 8
    property real trackInsideCornerSize: 2
    property real stopIndicatorSize: 4

    background: Item {
        x: control.orientation === Qt.Horizontal
           ? control.leftPadding
           : control.leftPadding + control.availableWidth / 2 - control.trackHeight / 2
        y: control.orientation === Qt.Horizontal
           ? control.topPadding + control.availableHeight / 2 - control.trackHeight / 2
           : control.topPadding
        implicitWidth: control.orientation === Qt.Horizontal ? 200 : control.trackHeight
        implicitHeight: control.orientation === Qt.Horizontal ? control.trackHeight : 200
        width: control.orientation === Qt.Horizontal ? control.availableWidth : control.trackHeight
        height: control.orientation === Qt.Horizontal ? control.trackHeight : control.availableHeight

        // Inactive track (справа/сверху от handle с gap)
        Rectangle {
            x: control.orientation === Qt.Horizontal
               ? Math.min(control.visualPosition * parent.width + control.thumbWidth / 2 + control.thumbTrackGap, parent.width)
               : 0
            y: control.orientation === Qt.Horizontal
               ? 0
               : Math.min(0, control.visualPosition * parent.height - control.thumbWidth / 2 - control.thumbTrackGap)
            width: control.orientation === Qt.Horizontal
                   ? Math.max(0, parent.width - x)
                   : parent.width
            height: control.orientation === Qt.Horizontal
                    ? parent.height
                    : Math.max(parent.height - y, parent.height)
            // radius: control.trackCornerSize
            radius: control.trackInsideCornerSize
            color: Config.colors.surfaceContainerHighest

            // Stop indicator (точка на конце)
            Rectangle {
                anchors.right: control.orientation === Qt.Horizontal ? parent.right : undefined
                anchors.horizontalCenter: control.orientation === Qt.Horizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: control.orientation === Qt.Horizontal ? parent.verticalCenter : undefined
                anchors.top: control.orientation === Qt.Horizontal ? undefined : parent.top
                width: control.stopIndicatorSize
                height: control.stopIndicatorSize
                radius: control.stopIndicatorSize / 2
                color: Config.colors.onSurfaceVariant
                // visible: control.visualPosition < 0.99
                visible: control.orientation === Qt.Horizontal ? control.visualPosition < 0.99
                                                               : 1.0 - control.visualPosition < 0.99

            }
        }

        // Active track (слева/снизу от handle с gap)
        Rectangle {
            x: 0
            y: control.orientation === Qt.Horizontal
               ? 0
               : Math.min(control.visualPosition * parent.height + control.thumbWidth / 2 + control.thumbTrackGap, parent.height)
            width: control.orientation === Qt.Horizontal
                   ? Math.max(0, control.visualPosition * parent.width - control.thumbWidth / 2 - control.thumbTrackGap)
                   : parent.width
            height: control.orientation === Qt.Horizontal
                    ? parent.height
                    : Math.max(0, parent.height - y)
            radius: control.trackInsideCornerSize
            color: control.enabled ? Config.colors.primary : Config.colors.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            Behavior on color {
                ColorAnimation { duration: Config.motion.duration.short4 }
            }
        }
    }

    handle: Item {
        x: control.orientation === Qt.Horizontal
           ? control.leftPadding + control.visualPosition * (control.availableWidth - width)
           : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.orientation === Qt.Horizontal
           ? control.topPadding + control.availableHeight / 2 - height / 2
           : control.topPadding + control.visualPosition * (control.availableHeight - height)
        implicitWidth: control.orientation === Qt.Horizontal ? control.thumbWidth : control.thumbHeight
        implicitHeight: control.orientation === Qt.Horizontal ? control.thumbHeight : control.thumbWidth

        // State layer (hover/pressed)
        Rectangle {
            anchors.centerIn: parent
            width: control.pressed ? 44 : (control.hovered ? 44 : 0)
            height: width
            radius: width / 2
            color: Config.colors.primary
            opacity: control.pressed ? 0.12 : (control.hovered ? 0.08 : 0)
            visible: control.enabled

            Behavior on width {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                    easing.type: Config.motion.easing.emphasized
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                }
            }
        }

        // Handle (thumb) - тонкий вертикальный для horizontal, горизонтальный для vertical
        Rectangle {
            anchors.centerIn: parent
            width: control.orientation === Qt.Horizontal ? control.thumbWidth : control.thumbHeight
            height: control.orientation === Qt.Horizontal ? control.thumbHeight : control.thumbWidth
            radius: control.orientation === Qt.Horizontal ? control.thumbWidth / 2 : control.thumbHeight / 2
            color: control.enabled ? Config.colors.primary : Config.colors.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            // M3 elevation через subtle border (вместо DropShadow)
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, 0.1)

            Behavior on color {
                ColorAnimation {
                    duration: Config.motion.duration.short4
                }
            }
        }
    }
}
