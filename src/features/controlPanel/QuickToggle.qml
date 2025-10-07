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
    width: 48
    height: 48
    iconSize: 24
    radius: 12

    backgroundColor: toggled ? Config.colors.secondaryContainer : Config.colors.surfaceContainerLow
    iconColor: toggled ? Config.colors.onSecondaryContainer : Config.colors.onSurfaceVariant

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
