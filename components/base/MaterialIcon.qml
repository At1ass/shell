import QtQuick
import Qt5Compat.GraphicalEffects
import qs.config

Rectangle {
    id: root

    // property alias iconSource: iconImage.source
    // property alias iconSource: null
    property string iconStyle: "bold" // bold, fill, duotone, regular, thin, light
    property string iconName: ""
    property string fallbackText: ""
    property bool enabled: true
    property alias ripple: ripple
    property alias rippleAnimation: rippleAnimation

    // Color properties
    property color backgroundColor: "transparent"
    property color hoverColor: Qt.alpha(Config.colors.primary, 0.12)
    property color pressColor: Qt.alpha(Config.colors.primary, 0.16)
    property color disabledColor: Qt.alpha(Config.colors.surfaceText, 0.12)
    property color iconColor: enabled ? Config.colors.primary : Config.colors.surfaceText
    property color rippleColor: Config.colors.primary

    // Size properties
    property int iconSize: 24

    // Ripple effect
    property bool enableRipple: true
    property int rippleDuration: Config.motion.duration.medium2

    width: 30
    height: 30
    radius: 24

    // color: !enabled ? disabledColor :
    // mouseArea.pressed ? pressColor :
    // mouseArea.containsMouse ? hoverColor :
    // backgroundColor

    // Auto-resolve icon path if iconName is provided
    readonly property string resolvedIconSource: {
        // if (iconSource)  return iconSource
        if (iconName)
            return `root:icons/SVGs/${iconStyle}/${iconName}-${iconStyle}`;
        // if (iconName) return "root:icons/SVGs/regular/speaker-simple-x"
        return "";
    }

    // Color transitions
    Behavior on color {
        ColorAnimation {
            duration: Config.motion.duration.short3
            easing.type: Config.motion.easing.standard
            easing.bezierCurve: Config.motion.easing.standardPoints
        }
    }

    // Ripple effect container
    Item {
        id: rippleContainer
        anchors.fill: parent
        clip: true
        visible: root.enableRipple

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: rippleContainer.width
                height: rippleContainer.height
                radius: root.radius
            }
        }

        Rectangle {
            id: ripple
            width: 0
            height: 0
            radius: width / 2
            color: Qt.alpha(root.rippleColor, 0.2)
            anchors.centerIn: parent
            visible: false

            PropertyAnimation {
                id: rippleAnimation
                target: ripple
                properties: "width,height"
                duration: root.rippleDuration
                easing.type: Config.motion.easing.standard
                easing.bezierCurve: Config.motion.easing.standardPoints
                onStarted: ripple.visible = true
                onFinished: {
                    ripple.width = 0;
                    ripple.height = 0;
                    ripple.visible = false;
                }
            }
        }
    }

    // Icon
    Image {
        id: iconImage
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.resolvedIconSource
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        cache: true
        asynchronous: true
        visible: status === Image.Ready

        // Color overlay for SVG icons
        ColorOverlay {
            anchors.fill: parent
            source: parent
            color: root.iconColor
            visible: parent.visible

            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Fallback text when icon fails to load
    Text {
        id: fallbackIcon
        anchors.centerIn: parent
        text: root.fallbackText
        color: root.iconColor
        font.pixelSize: 20
        font.weight: Font.Medium
        visible: !iconImage.visible && fallbackText

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
