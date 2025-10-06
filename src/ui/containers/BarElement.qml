import QtQuick
import qs.src.core.config

Rectangle {
    id: root

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
    property color backgroundColor: Config.colors.surfaceContainerHigh
    property color expandedColor: Config.colors.primaryContainer
    property real customRadius: Config.shape.large
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

    // Base styling using Config
    color: expanded ? expandedColor : backgroundColor
    radius: customRadius
    height: customHeight

    // Dynamic width calculation
    width: {
        if (expandedWidth > 0 && expanded) return expandedWidth
        return Math.max(minWidth, contentContainer.implicitWidth + Config.spacing.medium)
    }

    // Primary surface tint for consistency
    Rectangle {
        anchors.fill: parent
        color: Config.colors.primary
        opacity: 0.05
        radius: parent.radius
    }

    // Material Design state layer
    Rectangle {
        id: stateLayer
        anchors.fill: parent
        radius: parent.radius
        color: Config.colors.onSurface
        opacity: {
            if (!clickable && !hoverable) return 0.0
            if (pressed) return 0.12
            if (hovered) return 0.08
            return 0.0
        }

        Behavior on opacity {
            enabled: root.animated
            NumberAnimation {
                duration: Config.animations.durationShort
                easing.type: Easing.OutQuad
            }
        }
    }

    // Content container
    Item {
        id: contentContainer
        anchors.centerIn: parent
        anchors.margins: Config.spacing.small
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
        anchors.margins: expandOnHover ? -Config.spacing.small : 0
        hoverEnabled: clickable || hoverable || expandOnHover
        enabled: clickable || hoverable || expandOnHover
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function(mouse) {
            console.log("BarElement clicked, clickable:", clickable)
            if (root.clickHandler) {
                root.clickHandler(mouse)
            } else {
                root.clicked(mouse)
            }

            // Пропускаем событие дальше, если есть дочерние MouseArea
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
    Behavior on width {
        enabled: root.animated
        NumberAnimation {
            duration: Config.animations.durationMedium
            easing.type: Easing.OutQuad
        }
    }

    Behavior on color {
        enabled: root.animated
        ColorAnimation {
            duration: Config.animations.durationMedium
            easing.type: Easing.OutQuad
        }
    }

    // Scale animation on press
    scale: (pressed && clickable) ? 0.95 : 1.0
    Behavior on scale {
        enabled: root.animated
        NumberAnimation {
            duration: Config.animations.durationShort
            easing.type: Easing.OutQuad
        }
    }
}
