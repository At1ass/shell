import QtQuick
import qs.config

Item {
    id: root

    property string variant: "standard"
    property string iconName: "star"
    property int iconSize: Tokens.iconSize.large
    property color iconColor: defaultIconColor()
    property bool enabled: true

    property int containerSize: 40
    property int touchTargetSize: Tokens.touchTarget.minimum

    signal clicked(var mouse)
    signal pressed()
    signal released()

    implicitWidth: touchTargetSize
    implicitHeight: touchTargetSize

    Rectangle {
        id: container
        anchors.centerIn: parent
        width: containerSize
        height: containerSize
        radius: containerSize / 2

        color: containerColor()
        border.width: variant === "outlined" ? 1 : 0
        border.color: variant === "outlined" ? GreeterTheme.outline : "transparent"

        opacity: root.enabled ? 1.0 : 0.38

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
            }
        }

        StateLayer {
            layerColor: stateLayerColor()
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
        }

        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.iconName
            fontSize: root.iconSize
            iconColor: root.enabled ? root.iconColor : Qt.alpha(root.iconColor, 0.38)
            backgroundColor: "transparent"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled

        onClicked: function(mouse) { root.clicked(mouse) }
        onPressed: { root.pressed() }
        onReleased: { root.released() }
    }

    function containerColor() {
        if (!root.enabled) return GreeterTheme.surfaceContainerHigh
        switch (variant) {
        case "filled": return GreeterTheme.primary
        case "tonal": return GreeterTheme.secondaryContainer
        case "outlined":
        case "standard":
        default: return "transparent"
        }
    }

    function defaultIconColor() {
        switch (variant) {
        case "filled": return GreeterTheme.onPrimary
        case "tonal": return GreeterTheme.onSecondaryContainer
        case "outlined":
        case "standard":
        default: return GreeterTheme.onSurfaceVariant
        }
    }

    function stateLayerColor() {
        switch (variant) {
        case "filled": return GreeterTheme.onPrimary
        case "tonal": return GreeterTheme.onSecondaryContainer
        default: return GreeterTheme.onSurface
        }
    }
}
