import QtQuick
import qs.src.core.config

// Optimized Material Design 3 Icon component
// Removed: ripple effects, OpacityMask, layer.enabled for better performance
Rectangle {
    id: root

    property string iconName: ""
    readonly property string fontFamily: "Material Symbols Rounded"
    property int fontSize: Config.typography.bodyLarge.size
    property bool enabled: true
    property real fill: enabled ? 1 : 0
    property int grade: 0

    // Color properties
    property color backgroundColor: "transparent"
    property color iconColor: enabled ? Config.colors.primary : Config.colors.surfaceText

    width: 30
    height: 30
    radius: 24

    color: backgroundColor

    // Color transitions
    Behavior on color {
        ColorAnimation {
            duration: Config.motion.duration.short3
            easing.type: Config.motion.easing.standard
            easing.bezierCurve: Config.motion.easing.standardPoints
        }
    }

    // Icon text using optimized MaterialText
    MaterialText {
        id: icon
        anchors.centerIn: parent
        text: root.iconName
        color: root.iconColor
        font.family: root.fontFamily
        font.pointSize: root.fontSize
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
