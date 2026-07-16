import QtQuick
import QtQuick.Controls
import qs.src.core.config

// Material Design 3 Slider (2024 spec)
Slider {
    id: control

    stepSize: 0.01
    from: 0.0
    to: 1.0

    implicitWidth: orientation === Qt.Horizontal ? 200 : 48
    implicitHeight: orientation === Qt.Horizontal ? 48 : 200

    property real trackHeight: 24
    property real thumbWidth: 4
    property real thumbHeight: 48
    property real thumbTrackGap: 6
    property real trackCornerSize: 8
    property real trackInsideCornerSize: 2
    property real stopIndicatorSize: 6

    background: Item {
        x: control.orientation === Qt.Horizontal
           ? control.leftPadding
           : control.leftPadding + control.availableWidth / 2 - control.trackHeight / 2
        y: control.orientation === Qt.Horizontal
           ? control.topPadding + control.availableHeight / 2 - control.trackHeight / 2
           : control.topPadding
        width: control.orientation === Qt.Horizontal ? control.availableWidth : control.trackHeight
        height: control.orientation === Qt.Horizontal ? control.trackHeight : control.availableHeight

        // Inactive track (right/top of handle with gap)
        Rectangle {
            x: control.orientation === Qt.Horizontal
               ? Math.min(control.visualPosition * parent.width + control.thumbWidth / 2 + control.thumbTrackGap, parent.width)
               : 0
            y: 0
            width: control.orientation === Qt.Horizontal
                   ? Math.max(0, parent.width - x)
                   : parent.width
            height: control.orientation === Qt.Horizontal
                    ? parent.height
                    : Math.max(0, control.visualPosition * parent.height - control.thumbWidth / 2 - control.thumbTrackGap)
            radius: control.trackInsideCornerSize
            color: Theme.surfaceContainerHighest


            // Stop indicator (dot at the end of the track)
            Rectangle {
                anchors {
                    right: control.orientation === Qt.Horizontal ? parent.right : undefined
                    horizontalCenter: control.orientation === Qt.Horizontal ? undefined : parent.horizontalCenter
                    verticalCenter: control.orientation === Qt.Horizontal ? parent.verticalCenter : undefined
                    top: control.orientation === Qt.Horizontal ? undefined : parent.top
                    topMargin: control.orientation === Qt.Horizontal ? 0 : control.stopIndicatorSize / 2
                    rightMargin: control.orientation === Qt.Horizontal ? control.stopIndicatorSize / 2 : 0
                }
                width: control.stopIndicatorSize
                height: control.stopIndicatorSize
                radius: control.stopIndicatorSize / 2
                color: Theme.onSurfaceVariant
                // visible: control.visualPosition < 0.99
                visible: control.orientation === Qt.Horizontal ? control.visualPosition < 0.99
                                                               : 1.0 - control.visualPosition < 0.99

            }
        }

        // Active track (left/bottom of handle with gap)
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
            color: control.enabled ? Theme.primary : Theme.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            Behavior on color {
                ColorAnimation { duration: Tokens.motion.duration.short4 }
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
            color: Theme.primary
            opacity: control.pressed ? 0.12 : (control.hovered ? 0.08 : 0)
            visible: control.enabled

            Behavior on width {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.emphasized
                    easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }

        // Handle (thumb)
        Rectangle {
            anchors.centerIn: parent
            width: control.orientation === Qt.Horizontal ? control.thumbWidth : control.thumbHeight
            height: control.orientation === Qt.Horizontal ? control.thumbHeight : control.thumbWidth
            radius: control.orientation === Qt.Horizontal ? control.thumbWidth / 2 : control.thumbHeight / 2
            color: control.enabled ? Theme.primary : Theme.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            // M3 elevation via subtle border
            border.width: 0.5
            border.color: Qt.alpha(Theme.shadow, 0.1)

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }
    }
}
