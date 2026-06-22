import QtQuick
import qs.src.core.config
import qs.src.ui.feedback

Rectangle {
    id: root

    // Bar widget interface (expected by StatusBar/BarWidgetLoader):
    // - property var widgetConfig: full config entry for the widget
    // - property var widgetSettings: widgetConfig?.settings ?? {}
    // - optional: widgetConfig.clickAction for GlobalStates handler

    // Content properties
    property alias content: contentLoader.sourceComponent
    property list<QtObject> nonVisualChildren
    default property alias children: contentContainer.children

    // Interaction states
    property bool hovered: mouseArea.containsMouse
    property bool pressed: mouseArea.pressed
    property bool expanded: false

    // Configuration
    property bool animated: true
    property bool clickable: false
    property bool hoverable: false
    property bool expandOnHover: false

    // Styling overrides
    property color backgroundColor: Theme.surfaceContainerHigh
    property color expandedColor: Theme.primaryContainer
    property real customRadius: Tokens.shape.large
    property int customHeight: 32
    property int minWidth: 48
    property int expandedWidth: 0

    // Mouse interaction signals
    signal clicked(MouseEvent mouse)
    signal entered()
    signal exited()
    signal wheeled(var wheel)

    // Custom handlers
    property var clickHandler: null
    property var wheelHandler: null

    // Base styling using design tokens
    color: expanded ? expandedColor : backgroundColor
    radius: customRadius
    // height: customHeight

    implicitHeight: customHeight
    // Dynamic width calculation
    implicitWidth: {
        if (expandedWidth > 0 && expanded) return expandedWidth
        return Math.max(minWidth, contentContainer.implicitWidth + Tokens.spacing.medium)
    }
    width: implicitWidth
    // height: implicitHeight
    // implicitWidth: width
    // implicitHeight: height

    // Primary surface tint for consistency
    Rectangle {
        anchors.fill: parent
        color: Theme.primary
        opacity: 0.05
        radius: root.radius
    }

    // Material Design 3 state layer (hover/press feedback) — opacities and easing from Tokens.
    StateLayer {
        layerColor: Theme.onSurface
        hovered: root.hovered && (root.clickable || root.hoverable)
        pressed: root.pressed && root.clickable
        showFocusRing: false
    }

    // Content container
    Item {
        id: contentContainer
        anchors.centerIn: parent
        anchors.margins: Tokens.spacing.small
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }

    // Fallback loader for component-based content
    Loader {
        id: contentLoader
        anchors.centerIn: parent
        active: root.content !== undefined
        visible: active
    }

    // Mouse interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: expandOnHover ? -Tokens.spacing.small : 0
        hoverEnabled: clickable || hoverable || expandOnHover
        enabled: clickable || hoverable || expandOnHover
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function(mouse) {
            if (root.clickHandler) {
                root.clickHandler(mouse)
            } else {
                root.clicked(mouse)
            }

            // Let the event fall through to child MouseAreas when this element is not itself
            // clickable and has no handler of its own.
            if (!clickable && !root.clickHandler) {
                mouse.accepted = false
            }
        }

        onEntered: {
            if (expandOnHover) root.expanded = true
            root.entered()
        }
        onExited: {
            if (expandOnHover) root.expanded = false
            root.exited()
        }

        onWheel: function(wheel) {
            if (root.wheelHandler) {
                root.wheelHandler(wheel)
            } else {
                root.wheeled(wheel)
            }
        }
    }

    // Animations
    // Behavior on width {
    Behavior on implicitWidth {
        enabled: root.animated
        NumberAnimation {
            duration: Tokens.motion.duration.medium2
            easing.type: Tokens.motion.easing.emphasized
            easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
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

    // Scale feedback on press
    scale: (pressed && clickable) ? 0.95 : 1.0
    Behavior on scale {
        enabled: root.animated
        NumberAnimation {
            duration: Tokens.motion.duration.short3
            easing.type: Tokens.motion.easing.standard
            easing.bezierCurve: Tokens.motion.easing.standardPoints
        }
    }
}
