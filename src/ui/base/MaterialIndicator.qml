import QtQuick
import qs.src.core.config

Rectangle {
    id: root

    property string size: "small"        // small, medium, large
    property string colorRole: "outline" // any color from Theme
    property bool animated: true
    property string shape: "circle"      // circle, rounded, square

    // Sizes per Material Design
    readonly property var sizes: ({
        "extraSmall": 4,
        "small": 8,
        "medium": 12,
        "large": 16,
        "extraLarge": 20
    })

    // Automatic sizing
    width: sizes[size] || sizes.small
    height: width

    // Automatic radius depending on shape
    radius: {
        switch(shape) {
            case "circle": return width / 2
            case "rounded": return Tokens.shape.extraSmall
            case "square": return 0
            default: return width / 2
        }
    }

    // Automatic color from tokens
    color: Theme[colorRole] || Theme.outline

    // Animations
    Behavior on width {
        enabled: root.animated
        NumberAnimation {
            duration: Tokens.motion.duration.short2
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    Behavior on height {
        enabled: root.animated
        NumberAnimation {
            duration: Tokens.motion.duration.short2
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    Behavior on color {
        enabled: root.animated
        ColorAnimation {
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }

    // Size validation
    onSizeChanged: {
        if (!sizes[size]) {
            console.warn(`MaterialIndicator: unknown size "${size}", falling back to small`)
        }
    }
}