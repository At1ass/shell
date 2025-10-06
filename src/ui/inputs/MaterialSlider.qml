import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.src.core.config

// Material Design 3 Slider (2024 spec)
Slider {
    id: control

    stepSize: 0.01
    from: 0.0
    to: 1.0

    implicitWidth: 200
    implicitHeight: 48

    property real trackHeight: 16
    property real thumbWidth: 4
    property real thumbHeight: 44
    property real thumbTrackGap: 6
    property real trackCornerSize: 8
    property real trackInsideCornerSize: 2
    property real stopIndicatorSize: 4

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - control.trackHeight / 2
        implicitWidth: 200
        implicitHeight: control.trackHeight
        width: control.availableWidth
        height: control.trackHeight

        // Inactive track (справа от handle с gap)
        Rectangle {
            x: Math.min(control.visualPosition * parent.width + control.thumbWidth / 2 + control.thumbTrackGap, parent.width)
            width: Math.max(0, parent.width - x)
            height: parent.height
            radius: control.trackCornerSize
            color: Config.colors.surfaceContainerHighest

            // Stop indicator (точка на конце)
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: control.stopIndicatorSize
                height: control.stopIndicatorSize
                radius: control.stopIndicatorSize / 2
                color: Config.colors.onSurfaceVariant
                visible: control.visualPosition < 0.99
            }
        }

        // Active track (слева от handle с gap)
        Rectangle {
            width: Math.max(0, control.visualPosition * parent.width - control.thumbWidth / 2 - control.thumbTrackGap)
            height: parent.height
            radius: control.trackInsideCornerSize
            color: control.enabled ? Config.colors.primary : Config.colors.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            Behavior on color {
                ColorAnimation { duration: Config.motion.duration.short4 }
            }
        }
    }

    handle: Item {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: control.thumbWidth
        implicitHeight: control.thumbHeight

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

        // Handle (thumb) - тонкий вертикальный
        Rectangle {
            anchors.centerIn: parent
            width: control.thumbWidth
            height: control.thumbHeight
            radius: control.thumbWidth / 2
            color: control.enabled ? Config.colors.primary : Config.colors.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            // Elevation
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 1
                radius: 2
                samples: 5
                color: Qt.rgba(0, 0, 0, 0.2)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Config.motion.duration.short4
                }
            }
        }
    }
}