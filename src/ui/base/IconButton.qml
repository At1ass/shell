import QtQuick
import qs.src.core.config
import qs.src.ui.feedback

// Material Design 3 Icon Button
Item {
    id: root

    // Button properties
    property string variant: "standard"  // standard, filled, tonal, outlined
    property string iconName: "star"
    property int iconSize: Tokens.iconSize.large  // 24dp default
    property color iconColor: defaultIconColor()

    // Size properties
    property int containerSize: 40
    property int touchTargetSize: Tokens.touchTarget.minimum  // 48dp

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
        border.color: variant === "outlined"
                ? (root.enabled ? Theme.outline : Qt.alpha(Theme.onSurface, Tokens.state.disabledContainerOpacity))
                : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
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
            iconColor: root.enabled ? root.iconColor : Qt.alpha(root.iconColor, Tokens.state.disabledContentOpacity)
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
        if (!root.enabled) {
            // Filled/tonal show a faint disabled fill; standard/outlined stay transparent.
            return (variant === "filled" || variant === "tonal")
                ? Qt.alpha(Theme.onSurface, Tokens.state.disabledContainerOpacity)
                : "transparent"
        }

        switch (variant) {
        case "filled":
            return Theme.primary
        case "tonal":
            return Theme.secondaryContainer
        case "outlined":
        case "standard":
        default:
            return "transparent"
        }
    }

    function defaultIconColor() {
        switch (variant) {
        case "filled":
            return Theme.onPrimary
        case "tonal":
            return Theme.onSecondaryContainer
        case "outlined":
        case "standard":
        default:
            return Theme.onSurfaceVariant
        }
    }

    function stateLayerColor() {
        switch (variant) {
        case "filled":
            return Theme.onPrimary
        case "tonal":
            return Theme.onSecondaryContainer
        default:
            return Theme.onSurface
        }
    }
}
