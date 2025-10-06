import QtQuick
import Qt5Compat.GraphicalEffects
import qs.src.core.config

Rectangle {
    id: root

    property string iconName: ""
    readonly property string fontFamily: "Material Symbols Rounded"
    property int fontSize: Config.typography.bodyLarge.size
    property bool enabled: true
    property alias ripple: ripple
    property alias rippleAnimation: rippleAnimation
    property real fill: enabled ? 1 : 0
    property int grade: 0

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

    color: !enabled ? disabledColor : backgroundColor

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

    // Fallback text when icon fails to load
    MaterialText {
        id: fallbackIcon
        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColor
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        renderType: Text.NativeRendering
        textFormat: Text.PlainText

        font.variableAxes: ({
            FILL: root.fill.toFixed(1),
            GRAD: root.grade,
            opsz: fontInfo.pixelSize,
            wght: fontInfo.weight
        })

        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
