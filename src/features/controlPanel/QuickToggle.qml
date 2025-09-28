import QtQuick
import qs.src.core.config
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.ui.base

ClickableIcon {
    id: root

    property bool toggled: false
    property string toggleIcon: "wifi"

    iconName: toggleIcon
    iconStyle: toggled ? "fill" : "bold"
    iconSize: 18
    width: 36
    height: 36
    radius: 18

    backgroundColor: toggled ? Config.colors.primary : Config.colors.surfaceContainerHigh
    iconColor: toggled ? Config.colors.primaryText : Config.colors.surfaceText

    Behavior on backgroundColor {
        ColorAnimation {
            duration: Config.motion.duration.short3
            easing.type: Config.motion.easing.standard
        }
    }

    Behavior on iconColor {
        ColorAnimation {
            duration: Config.motion.duration.short3
            easing.type: Config.motion.easing.standard
        }
    }
}