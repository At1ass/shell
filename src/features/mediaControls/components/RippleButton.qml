import QtQuick
import qs.src.core.config
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.ui.base

ClickableIcon {
    id: root

    property alias text: root.iconName
    property string buttonType: "icon" // "icon", "text", "filled"
    property bool playing: false

    // Override ClickableIcon properties for media controls
    backgroundColor: buttonType === "filled" ? Config.colors.primary : "transparent"
    iconColor: enabled ? (buttonType === "filled" ? Config.colors.onPrimary : Config.colors.primary) : Config.colors.onSurface

    // Morphing radius for play button
    radius: playing ? 12 : 24

    // Radius animation
    Behavior on radius {
        NumberAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.emphasized
            easing.bezierCurve: Config.motion.easing.emphasizedPoints
        }
    }

    // Elevation shadow for filled buttons
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.leftMargin: 1
        radius: parent.radius
        color: Qt.alpha("#000000", buttonType === "filled" ? 0.1 : 0)
        z: -1
        visible: buttonType === "filled"

        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }
}
