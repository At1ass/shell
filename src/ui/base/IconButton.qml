import QtQuick
import qs.src.core.config
import qs.src.ui.feedback

// Material Design 3 Icon Button
Item {
    id: root

    // Button properties
    property string variant: "standard"  // standard, filled, tonal, outlined
    property string iconName: "star"
    property int iconSize: Config.iconSize.large  // 24dp default
    property color iconColor: defaultIconColor()
    property bool enabled: true

    // Size properties
    property int containerSize: 40
    property int touchTargetSize: Config.touchTarget.minimum  // 48dp

    // Signals
    signal clicked(var mouse)
    signal pressed()
    signal released()

    // Dimensions
    implicitWidth: touchTargetSize
    implicitHeight: touchTargetSize

    // Container
    Rectangle {
        id: container
        anchors.centerIn: parent
        width: containerSize
        height: containerSize
        radius: containerSize / 2

        color: containerColor()
        border.width: variant === "outlined" ? 1 : 0
        border.color: variant === "outlined" ? Config.colors.outline : "transparent"

        opacity: root.enabled ? 1.0 : 0.38

        Behavior on color {
            ColorAnimation {
                duration: Config.motion.duration.short4
                easing.type: Config.motion.easing.standard
            }
        }

        // State layer
        StateLayer {
            layerColor: stateLayerColor()
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
        }

        // Icon
        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.iconName
            fontSize: root.iconSize
            iconColor: root.enabled ? root.iconColor : Qt.alpha(root.iconColor, 0.38)
            backgroundColor: "transparent"
        }
    }

    // Mouse area (full touch target)
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled

        onClicked: function(mouse) {
            root.clicked(mouse)
        }

        onPressed: {
            root.pressed()
        }

        onReleased: {
            root.released()
        }
    }

    // Helper functions
    function containerColor() {
        if (!root.enabled) return Config.colors.surfaceContainerHigh

        switch (variant) {
        case "filled":
            return Config.colors.primary
        case "tonal":
            return Config.colors.secondaryContainer
        case "outlined":
        case "standard":
        default:
            return "transparent"
        }
    }

    function defaultIconColor() {
        switch (variant) {
        case "filled":
            return Config.colors.onPrimary
        case "tonal":
            return Config.colors.onSecondaryContainer
        case "outlined":
        case "standard":
        default:
            return Config.colors.onSurfaceVariant
        }
    }

    function stateLayerColor() {
        switch (variant) {
        case "filled":
            return Config.colors.onPrimary
        case "tonal":
            return Config.colors.onSecondaryContainer
        default:
            return Config.colors.onSurface
        }
    }
}
